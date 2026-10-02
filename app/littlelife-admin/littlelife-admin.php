<?php

declare(strict_types=1);

namespace Grav\Plugin;

use Grav\Common\Plugin;
use Grav\Plugin\LittleLifeAdmin\LittleLifeController;
use RocketTheme\Toolbox\Event\Event;

spl_autoload_register(static function (string $class): void {
    if ($class === LittleLifeController::class) {
        require_once __DIR__ . '/classes/LittleLifeController.php';
    }
});

final class LittleLifeAdminPlugin extends Plugin
{
    public static function getSubscribedEvents(): array
    {
        return [
            'onApiRegisterRoutes' => ['onApiRegisterRoutes', 0],
            'onApiSidebarItems' => ['onApiSidebarItems', 0],
            'onApiPluginPageInfo' => ['onApiPluginPageInfo', 0],
        ];
    }

    public function onApiRegisterRoutes(Event $event): void
    {
        require_once __DIR__ . '/classes/LittleLifeController.php';
        $routes = $event['routes'];
        $routes->get('/littlelife/entries', [LittleLifeController::class, 'entries']);
        $routes->get('/littlelife/entries/{id}', [LittleLifeController::class, 'entry']);
        $routes->post('/littlelife/entries', [LittleLifeController::class, 'save']);
        $routes->post('/littlelife/entries/{id}/media', [LittleLifeController::class, 'upload']);
        $routes->get('/littlelife/integrity', [LittleLifeController::class, 'integrity']);
        $routes->post('/littlelife/rebuild', [LittleLifeController::class, 'rebuild']);
        $routes->post('/littlelife/export', [LittleLifeController::class, 'export']);
        $routes->get('/littlelife/exports/{filename}', [LittleLifeController::class, 'downloadExport']);
    }

    public function onApiSidebarItems(Event $event): void
    {
        $items = $event['items'];
        $items[] = [
            'id' => 'littlelife-admin',
            'plugin' => 'littlelife-admin',
            'label' => 'LittleLife 档案',
            'icon' => 'fa-solid fa-baby',
            'route' => '/plugin/littlelife-admin',
            'priority' => 95,
            'badge' => null,
        ];
        $event['items'] = $items;
    }

    public function onApiPluginPageInfo(Event $event): void
    {
        if ($event['plugin'] !== 'littlelife-admin') {
            return;
        }
        $event['definition'] = [
            'id' => 'littlelife-admin',
            'plugin' => 'littlelife-admin',
            'title' => 'LittleLife 档案',
            'icon' => 'fa-solid fa-baby',
            'page_type' => 'component',
            'actions' => [],
        ];
    }
}
