<?php

declare(strict_types=1);

namespace Grav\Plugin\LittleLifeAdmin;

use DateTimeImmutable;
use DateTimeZone;
use Grav\Framework\Psr7\Response;
use Grav\Plugin\Api\Controllers\AbstractApiController;
use Grav\Plugin\Api\Exceptions\NotFoundException;
use Grav\Plugin\Api\Exceptions\ValidationException;
use Grav\Plugin\Api\Response\ApiResponse;
use Psr\Http\Message\ResponseInterface;
use Psr\Http\Message\ServerRequestInterface;
use Psr\Http\Message\UploadedFileInterface;
use RuntimeException;
use ZipArchive;

final class LittleLifeController extends AbstractApiController
{
    private const ID_PATTERN = '/^[0-9]{8}-[a-z0-9]+(?:-[a-z0-9]+)*$/';
    private const TYPES = ['story', 'milestone', 'note'];
    private const EXTENSIONS = [
        'jpg', 'jpeg', 'png', 'gif', 'webp', 'heic', 'heif', 'avif',
        'mp4', 'mov', 'm4v', 'webm', 'mkv', 'avi',
        'mp3', 'm4a', 'aac', 'wav', 'flac', 'ogg', 'opus',
    ];

    public function entries(ServerRequestInterface $request): ResponseInterface
    {
        $this->requirePermission($request, 'api.littlelife.read');
        $items = [];
        foreach ($this->entryFiles() as $path) {
            $record = $this->parseEntry($path);
            $items[] = [
                'id' => $record['header']['id'],
                'title' => $record['header']['title'],
                'date' => $record['header']['date'],
                'type' => $record['header']['type'],
                'tags' => $record['header']['tags'] ?? [],
                'media_count' => count($record['header']['media']),
            ];
        }
        usort($items, static fn(array $a, array $b): int => strcmp((string) $b['date'], (string) $a['date']));
        return ApiResponse::ok(['entries' => $items, 'count' => count($items)]);
    }

    public function entry(ServerRequestInterface $request): ResponseInterface
    {
        $this->requirePermission($request, 'api.littlelife.read');
        $id = $this->validatedId($this->getRouteParam($request, 'id'));
        return ApiResponse::ok($this->serializeEntry($this->findEntry($id)));
    }

    public function save(ServerRequestInterface $request): ResponseInterface
    {
        $this->requirePermission($request, 'api.littlelife.write');
        $body = $this->getRequestBody($request);
        return $this->withLock(function () use ($body, $request): ResponseInterface {
            $id = isset($body['id']) && $body['id'] !== '' ? $this->validatedId((string) $body['id']) : null;
            $title = trim((string) ($body['title'] ?? ''));
            $content = str_replace(["\r\n", "\r"], "\n", (string) ($body['content'] ?? ''));
            $type = (string) ($body['type'] ?? 'story');
            $tags = $this->normalizeTags($body['tags'] ?? []);
            if ($title === '' || mb_strlen($title) > 200) {
                throw new ValidationException('标题不能为空且不能超过 200 个字符。');
            }
            if (strlen($content) > 1024 * 1024) {
                throw new ValidationException('正文不能超过 1 MiB。');
            }
            if (!in_array($type, self::TYPES, true)) {
                throw new ValidationException('记录类型无效。');
            }

            $now = new DateTimeImmutable('now', new DateTimeZone('Asia/Hong_Kong'));
            $existing = null;
            if ($id !== null) {
                $path = $this->findEntry($id);
                $existing = $this->parseEntry($path);
                $eventDate = $this->parseDate((string) $existing['header']['date']);
            } else {
                $eventDate = $this->parseDate((string) ($body['date'] ?? ''));
                $id = $eventDate->format('Ymd') . '-' . $this->slug($title);
                $id = $this->uniqueId($id);
                $path = $this->dataRoot() . '/entries/' . $eventDate->format('Y') . '/' . $id . '.md';
            }

            $header = [
                'id' => $id,
                'date' => $eventDate->format(DATE_ATOM),
                'title' => $title,
                'type' => $type,
                'tags' => $tags,
                'media' => $existing['header']['media'] ?? [],
                'visibility' => 'private',
                'created_at' => $existing['header']['created_at'] ?? $now->format(DATE_ATOM),
                'updated_at' => $now->format(DATE_ATOM),
            ];
            if ($existing !== null) {
                $this->snapshotEntry($path, $id);
            }
            $this->atomicWrite($path, $this->encodeEntry($header, $content));
            $this->validateAllEntries();
            $this->rebuildPages();
            $this->audit($request, $existing === null ? 'entry.create' : 'entry.update', $id, []);
            return ApiResponse::ok($this->serializeEntry($path));
        });
    }

    public function upload(ServerRequestInterface $request): ResponseInterface
    {
        $this->requirePermission($request, 'api.littlelife.write');
        $id = $this->validatedId($this->getRouteParam($request, 'id'));
        return $this->withLock(function () use ($request, $id): ResponseInterface {
            $path = $this->findEntry($id);
            $record = $this->parseEntry($path);
            $files = $this->flattenUploads($request->getUploadedFiles());
            $limit = (int) $this->config->get('plugins.littlelife-admin.max_upload_files', 20);
            if ($files === [] || count($files) > $limit) {
                throw new ValidationException("请选择 1 至 {$limit} 个媒体文件。 ");
            }
            $date = $this->parseDate((string) $record['header']['date']);
            $relativeDir = 'media-originals/' . $date->format('Y/Y-m-d');
            $targetDir = $this->dataRoot() . '/' . $relativeDir;
            $this->ensureDirectory($targetDir);
            $added = [];
            foreach ($files as $file) {
                $added[] = $this->storeUpload($file, $targetDir, $relativeDir);
            }
            foreach ($added as $item) {
                $record['header']['media'][] = '../../' . $item['relative'];
            }
            $record['header']['media'] = array_values(array_unique($record['header']['media']));
            $record['header']['updated_at'] = (new DateTimeImmutable('now', new DateTimeZone('Asia/Hong_Kong')))->format(DATE_ATOM);
            $this->snapshotEntry($path, $id);
            $this->atomicWrite($path, $this->encodeEntry($record['header'], $record['content']));
            $this->writeManifest();
            $this->validateAllEntries();
            $this->rebuildPages();
            $this->audit($request, 'media.upload', $id, array_column($added, 'relative'));
            return ApiResponse::ok(['entry' => $this->serializeEntry($path), 'uploaded' => $added]);
        });
    }

    public function integrity(ServerRequestInterface $request): ResponseInterface
    {
        $this->requirePermission($request, 'api.littlelife.read');
        $records = $this->validateAllEntries();
        $manifest = $this->verifyManifest();
        return ApiResponse::ok([
            'status' => 'ok',
            'records' => count($records),
            'media_checked' => $manifest['checked'],
            'checked_at' => gmdate('c'),
        ]);
    }

    public function rebuild(ServerRequestInterface $request): ResponseInterface
    {
        $this->requirePermission($request, 'api.littlelife.write');
        return $this->withLock(function () use ($request): ResponseInterface {
            $records = $this->validateAllEntries();
            $this->writeManifest();
            $result = $this->rebuildPages();
            $this->audit($request, 'archive.rebuild', null, []);
            return ApiResponse::ok($result + ['records' => count($records)]);
        });
    }

    public function export(ServerRequestInterface $request): ResponseInterface
    {
        $this->requirePermission($request, 'api.littlelife.read');
        return $this->withLock(function () use ($request): ResponseInterface {
            if (!class_exists(ZipArchive::class)) {
                throw new RuntimeException('PHP ZipArchive 扩展不可用。');
            }
            $this->validateAllEntries();
            $this->writeManifest();
            $exports = $this->dataRoot() . '/exports';
            $this->ensureDirectory($exports);
            $name = 'LittleLife-data-' . gmdate('Ymd\THis\Z') . '.zip';
            $path = $exports . '/' . $name;
            $zip = new ZipArchive();
            if ($zip->open($path, ZipArchive::CREATE | ZipArchive::EXCL) !== true) {
                throw new RuntimeException('无法创建导出文件。');
            }
            foreach (['README.md', 'profile', 'entries', 'media-originals', 'manifests'] as $item) {
                $source = $this->dataRoot() . '/' . $item;
                if (is_file($source)) {
                    $zip->addFile($source, 'LittleLife-data/' . $item);
                } elseif (is_dir($source)) {
                    $iterator = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($source, \FilesystemIterator::SKIP_DOTS));
                    foreach ($iterator as $file) {
                        if ($file->isFile()) {
                            $relative = substr($file->getPathname(), strlen($this->dataRoot()) + 1);
                            $zip->addFile($file->getPathname(), 'LittleLife-data/' . str_replace('\\', '/', $relative));
                        }
                    }
                }
            }
            $zip->close();
            $this->audit($request, 'archive.export', null, [$name]);
            return ApiResponse::ok([
                'filename' => $name,
                'bytes' => filesize($path),
                'download_url' => '/littlelife/exports/' . rawurlencode($name),
            ]);
        });
    }

    public function downloadExport(ServerRequestInterface $request): ResponseInterface
    {
        $this->requirePermission($request, 'api.littlelife.read');
        $filename = (string) $this->getRouteParam($request, 'filename');
        if (!preg_match('/^LittleLife-data-[0-9]{8}T[0-9]{6}Z\.zip$/', $filename)) {
            throw new ValidationException('导出文件名无效。');
        }
        $path = $this->dataRoot() . '/exports/' . $filename;
        if (!is_file($path)) {
            throw new NotFoundException('导出文件不存在。');
        }
        return new Response(200, [
            'Content-Type' => 'application/zip',
            'Content-Disposition' => 'attachment; filename="' . $filename . '"',
            'Content-Length' => (string) filesize($path),
            'Cache-Control' => 'no-store',
        ], fopen($path, 'rb'));
    }

    private function dataRoot(): string
    {
        $configured = rtrim((string) $this->config->get('plugins.littlelife-admin.data_root', '/littlelife-data'), '/');
        $real = realpath($configured);
        if ($real === false || !is_dir($real . '/entries') || !is_dir($real . '/media-originals')) {
            throw new RuntimeException('LittleLife 数据目录不可用。');
        }
        return $real;
    }

    private function derivedRoot(): string
    {
        $configured = rtrim((string) $this->config->get('plugins.littlelife-admin.derived_root', '/config/www/user/pages'), '/');
        $real = realpath($configured);
        if ($real === false || !is_dir($real)) {
            throw new RuntimeException('LittleLife 展示目录不可用。');
        }
        return $real;
    }

    private function entryFiles(): array
    {
        $files = glob($this->dataRoot() . '/entries/*/*.md') ?: [];
        sort($files, SORT_STRING);
        return $files;
    }

    private function validatedId(?string $id): string
    {
        if ($id === null || !preg_match(self::ID_PATTERN, $id)) {
            throw new ValidationException('记录 ID 无效。');
        }
        return $id;
    }

    private function findEntry(string $id): string
    {
        $matches = glob($this->dataRoot() . '/entries/*/' . $id . '.md') ?: [];
        if (count($matches) !== 1) {
            throw new NotFoundException('没有找到该记录。');
        }
        return $matches[0];
    }

    private function parseEntry(string $path): array
    {
        $text = file_get_contents($path);
        if ($text === false || !preg_match('/\A---\R(.*?)\R---\R?(.*)\z/s', $text, $match)) {
            throw new RuntimeException('记录格式无效：' . basename($path));
        }
        $header = yaml_parse($match[1]);
        if (!is_array($header)) {
            throw new RuntimeException('记录 YAML 无效：' . basename($path));
        }
        return ['header' => $header, 'content' => ltrim($match[2], "\r\n")];
    }

    private function encodeEntry(array $header, string $content): string
    {
        $yaml = yaml_emit($header, YAML_UTF8_ENCODING, YAML_LN_BREAK);
        $yaml = preg_replace('/\A---\R|\R\.\.\.\R?\z/', '', $yaml) ?? $yaml;
        return "---\n" . rtrim($yaml) . "\n---\n\n" . rtrim($content) . "\n";
    }

    private function serializeEntry(string $path): array
    {
        $record = $this->parseEntry($path);
        $date = $this->parseDate((string) $record['header']['date']);
        $media = [];
        foreach ($record['header']['media'] as $relative) {
            $absolute = realpath(dirname($path) . '/' . $relative);
            $media[] = [
                'path' => $relative,
                'name' => basename($relative),
                'bytes' => $absolute !== false && is_file($absolute) ? filesize($absolute) : null,
                'url' => '/archive/' . $date->format('Y') . '/' . $record['header']['id'] . '/' . rawurlencode(basename($relative)),
            ];
        }
        return [
            'id' => $record['header']['id'],
            'title' => $record['header']['title'],
            'date' => $record['header']['date'],
            'type' => $record['header']['type'],
            'tags' => $record['header']['tags'] ?? [],
            'content' => $record['content'],
            'media' => $media,
            'created_at' => $record['header']['created_at'],
            'updated_at' => $record['header']['updated_at'],
        ];
    }

    private function validateAllEntries(): array
    {
        $records = [];
        $ids = [];
        $root = $this->dataRoot();
        $originals = $root . '/media-originals/';
        foreach ($this->entryFiles() as $path) {
            $record = $this->parseEntry($path);
            $header = $record['header'];
            foreach (['id', 'date', 'title', 'type', 'media', 'visibility', 'created_at', 'updated_at'] as $field) {
                if (!array_key_exists($field, $header)) {
                    throw new RuntimeException(basename($path) . " 缺少字段 {$field}。");
                }
            }
            $id = $this->validatedId((string) $header['id']);
            if (isset($ids[$id])) {
                throw new RuntimeException("记录 ID 重复：{$id}");
            }
            $ids[$id] = true;
            $date = $this->parseDate((string) $header['date']);
            if (basename(dirname($path)) !== $date->format('Y')) {
                throw new RuntimeException("记录年份目录不匹配：{$id}");
            }
            if (!in_array($header['type'], self::TYPES, true) || $header['visibility'] !== 'private' || !is_array($header['media'])) {
                throw new RuntimeException("记录元数据无效：{$id}");
            }
            foreach ($header['media'] as $relative) {
                $absolute = realpath(dirname($path) . '/' . $relative);
                if ($absolute === false || !is_file($absolute) || !str_starts_with($absolute, $originals)) {
                    throw new RuntimeException("记录引用了无效媒体：{$id} / {$relative}");
                }
            }
            $records[] = ['path' => $path] + $record;
        }
        if ($records === []) {
            throw new RuntimeException('档案中至少需要一条记录。');
        }
        return $records;
    }

    private function rebuildPages(): array
    {
        $records = $this->validateAllEntries();
        $output = $this->derivedRoot();
        foreach (new \FilesystemIterator($output) as $item) {
            $this->removePath($item->getPathname());
        }
        $this->atomicWrite($output . '/.littlelife-derived', "Generated by LittleLife; safe to rebuild.\n");
        $profilePath = $this->dataRoot() . '/profile/child.yaml';
        $profile = yaml_parse_file($profilePath);
        if (!is_array($profile) || empty($profile['display_name'])) {
            throw new RuntimeException('宝宝资料缺少 display_name。');
        }
        $this->writePage($output . '/00.home/home.md', ['title' => (string) $profile['display_name'], 'template' => 'home', 'visible' => true], (string) ($profile['notice'] ?? '私人家庭成长档案。'));
        $this->writePage($output . '/01.timeline/timeline.md', ['title' => '时间线', 'template' => 'timeline', 'visible' => true], '按年份浏览成长记录。');
        $this->writePage($output . '/02.archive/default.md', ['title' => '档案', 'visible' => false], '');
        $mediaCount = 0;
        foreach ($records as $record) {
            $header = $record['header'];
            $date = $this->parseDate((string) $header['date']);
            $yearDir = $output . '/02.archive/' . $date->format('Y');
            if (!is_file($yearDir . '/default.md')) {
                $this->writePage($yearDir . '/default.md', ['title' => $date->format('Y'), 'visible' => false], '');
            }
            $pageDir = $yearDir . '/' . $header['id'];
            $this->ensureDirectory($pageDir);
            $names = [];
            foreach ($header['media'] as $relative) {
                $source = realpath(dirname($record['path']) . '/' . $relative);
                $name = basename($relative);
                if (isset($names[$name])) {
                    $name = (count($names) + 1) . '-' . $name;
                }
                if (!copy($source, $pageDir . '/' . $name)) {
                    throw new RuntimeException('无法生成媒体预览。');
                }
                $names[$name] = true;
                $mediaCount++;
            }
            $pageHeader = $header + [];
            $pageHeader['template'] = 'story';
            $pageHeader['visible'] = false;
            $pageHeader['media_files'] = array_keys($names);
            $pageHeader['source_record'] = substr($record['path'], strlen($this->dataRoot()) + 1);
            $this->writePage($pageDir . '/story.md', $pageHeader, $record['content']);
        }
        return ['status' => 'ok', 'media_copies' => $mediaCount, 'rebuilt_at' => gmdate('c')];
    }

    private function writePage(string $path, array $header, string $content): void
    {
        $this->atomicWrite($path, $this->encodeEntry($header, $content));
    }

    private function storeUpload(UploadedFileInterface $file, string $targetDir, string $relativeDir): array
    {
        if ($file->getError() !== UPLOAD_ERR_OK) {
            throw new ValidationException('媒体上传失败，错误代码：' . $file->getError());
        }
        $size = (int) ($file->getSize() ?? 0);
        $max = (int) $this->config->get('plugins.littlelife-admin.max_upload_bytes', 536870912);
        if ($size < 1 || $size > $max) {
            throw new ValidationException('媒体文件为空或超过大小限制。');
        }
        $original = basename((string) $file->getClientFilename());
        $extension = strtolower(pathinfo($original, PATHINFO_EXTENSION));
        if (!in_array($extension, self::EXTENSIONS, true)) {
            throw new ValidationException("不允许的媒体扩展名：{$extension}");
        }
        $base = pathinfo($original, PATHINFO_FILENAME);
        $base = preg_replace('~[\x00-\x1F\x7F\\/:*?"<>|]+~u', '-', $base) ?? 'media';
        $base = trim($base, ". -\t\n\r\0\x0B");
        if ($base === '') {
            $base = 'media';
        }
        $name = mb_substr($base, 0, 120) . '.' . $extension;
        $counter = 2;
        while (file_exists($targetDir . '/' . $name)) {
            $name = mb_substr($base, 0, 110) . '-' . $counter++ . '.' . $extension;
        }
        $temporary = $targetDir . '/.' . $name . '.upload-' . bin2hex(random_bytes(4));
        $file->moveTo($temporary);
        $mime = (new \finfo(FILEINFO_MIME_TYPE))->file($temporary) ?: '';
        if (!preg_match('#^(image|video|audio)/#', $mime)) {
            @unlink($temporary);
            throw new ValidationException("文件内容不是允许的图片、视频或音频：{$original}");
        }
        $target = $targetDir . '/' . $name;
        if (!rename($temporary, $target)) {
            @unlink($temporary);
            throw new RuntimeException('无法保存上传媒体。');
        }
        return [
            'name' => $name,
            'relative' => $relativeDir . '/' . $name,
            'bytes' => $size,
            'mime' => $mime,
            'sha256' => hash_file('sha256', $target),
        ];
    }

    private function writeManifest(): void
    {
        $root = $this->dataRoot();
        $files = [];
        $iterator = new \RecursiveIteratorIterator(new \RecursiveDirectoryIterator($root . '/media-originals', \FilesystemIterator::SKIP_DOTS));
        foreach ($iterator as $file) {
            if ($file->isFile()) {
                $relative = str_replace('\\', '/', substr($file->getPathname(), strlen($root) + 1));
                $files[$relative] = hash_file('sha256', $file->getPathname());
            }
        }
        ksort($files, SORT_STRING);
        $lines = [];
        foreach ($files as $relative => $hash) {
            $lines[] = $hash . '  ' . $relative;
        }
        $this->atomicWrite($root . '/manifests/media-sha256.txt', implode("\n", $lines) . ($lines ? "\n" : ''));
    }

    private function verifyManifest(): array
    {
        $root = $this->dataRoot();
        $manifest = $root . '/manifests/media-sha256.txt';
        if (!is_file($manifest)) {
            throw new RuntimeException('SHA-256 清单不存在。');
        }
        $checked = 0;
        foreach (file($manifest, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES) ?: [] as $line) {
            if (!preg_match('/^([a-f0-9]{64})  (.+)$/', $line, $match)) {
                throw new RuntimeException('SHA-256 清单格式无效。');
            }
            $path = realpath($root . '/' . $match[2]);
            if ($path === false || !str_starts_with($path, $root . '/media-originals/') || !hash_equals($match[1], hash_file('sha256', $path))) {
                throw new RuntimeException('媒体完整性校验失败：' . $match[2]);
            }
            $checked++;
        }
        return ['checked' => $checked];
    }

    private function atomicWrite(string $path, string $contents): void
    {
        $this->ensureDirectory(dirname($path));
        $temporary = dirname($path) . '/.' . basename($path) . '.tmp-' . bin2hex(random_bytes(4));
        if (file_put_contents($temporary, $contents, LOCK_EX) === false || !rename($temporary, $path)) {
            @unlink($temporary);
            throw new RuntimeException('原子写入失败：' . basename($path));
        }
    }

    private function snapshotEntry(string $path, string $id): void
    {
        $history = $this->dataRoot() . '/manifests/history/' . $id;
        $this->ensureDirectory($history);
        $target = $history . '/' . gmdate('Ymd\THis\Z') . '-' . bin2hex(random_bytes(2)) . '.md';
        if (!copy($path, $target)) {
            throw new RuntimeException('无法创建记录修改前快照。');
        }
    }

    private function audit(ServerRequestInterface $request, string $action, ?string $id, array $files): void
    {
        $user = $this->getUser($request);
        $username = method_exists($user, 'get') ? (string) $user->get('username') : 'admin';
        $line = json_encode([
            'timestamp' => gmdate('c'),
            'user' => $username ?: 'admin',
            'action' => $action,
            'entry_id' => $id,
            'files' => $files,
        ], JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE) . "\n";
        $path = $this->dataRoot() . '/manifests/audit.jsonl';
        $this->ensureDirectory(dirname($path));
        if (file_put_contents($path, $line, FILE_APPEND | LOCK_EX) === false) {
            throw new RuntimeException('无法写入审计记录。');
        }
    }

    private function withLock(callable $operation): mixed
    {
        $lockPath = $this->dataRoot() . '/.littlelife-write.lock';
        $handle = fopen($lockPath, 'c');
        if ($handle === false || !flock($handle, LOCK_EX | LOCK_NB)) {
            throw new RuntimeException('另一个档案写入任务正在执行，请稍后再试。');
        }
        try {
            return $operation();
        } finally {
            flock($handle, LOCK_UN);
            fclose($handle);
        }
    }

    private function parseDate(string $value): DateTimeImmutable
    {
        try {
            $date = new DateTimeImmutable($value);
        } catch (\Throwable) {
            throw new ValidationException('日期时间格式无效。');
        }
        if ($date->getOffset() === 0 && !preg_match('/(?:Z|[+-][0-9]{2}:[0-9]{2})$/', $value)) {
            throw new ValidationException('日期时间必须包含时区。');
        }
        return $date;
    }

    private function normalizeTags(mixed $tags): array
    {
        if (is_string($tags)) {
            $tags = preg_split('/[,，\n]+/u', $tags) ?: [];
        }
        if (!is_array($tags)) {
            throw new ValidationException('标签格式无效。');
        }
        $result = [];
        foreach ($tags as $tag) {
            $tag = trim((string) $tag);
            if ($tag !== '' && mb_strlen($tag) <= 40) {
                $result[] = $tag;
            }
        }
        return array_values(array_unique(array_slice($result, 0, 30)));
    }

    private function slug(string $title): string
    {
        $ascii = function_exists('transliterator_transliterate') ? transliterator_transliterate('Any-Latin; Latin-ASCII; Lower()', $title) : strtolower($title);
        $slug = preg_replace('/[^a-z0-9]+/', '-', (string) $ascii) ?? '';
        $slug = trim($slug, '-');
        return $slug !== '' ? substr($slug, 0, 48) : 'record-' . bin2hex(random_bytes(3));
    }

    private function uniqueId(string $base): string
    {
        $candidate = $base;
        $counter = 2;
        while ((glob($this->dataRoot() . '/entries/*/' . $candidate . '.md') ?: []) !== []) {
            $candidate = $base . '-' . $counter++;
        }
        return $candidate;
    }

    private function flattenUploads(array $items): array
    {
        $result = [];
        array_walk_recursive($items, static function (mixed $item) use (&$result): void {
            if ($item instanceof UploadedFileInterface) {
                $result[] = $item;
            }
        });
        return $result;
    }

    private function ensureDirectory(string $path): void
    {
        if (!is_dir($path) && !mkdir($path, 0770, true) && !is_dir($path)) {
            throw new RuntimeException('无法创建目录：' . $path);
        }
    }

    private function removePath(string $path): void
    {
        if (is_dir($path) && !is_link($path)) {
            foreach (new \FilesystemIterator($path) as $child) {
                $this->removePath($child->getPathname());
            }
            if (!rmdir($path)) {
                throw new RuntimeException('无法清理旧展示目录。');
            }
        } elseif (!unlink($path)) {
            throw new RuntimeException('无法清理旧展示文件。');
        }
    }
}
