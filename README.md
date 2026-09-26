# L4D2 Keep End Credits

这是给以下两个插件配套使用的小型兼容补丁：

- `自选-换图类(投票换图)(v1.1)(fdxx, sorallll, HatsuneImagine)`
- `自选-换图类(自动换图)(v1.0.5)(Alex Dragokas, fdxx, sorallll)`

作用是把自动换图插件已有的cfg/sourcemod/map_changer.cfg
`mapchanger_finale_change_type` 固定为 `8`，让服务器在 End Credits/统计字幕播放完毕后，
再加载投票选中或自动配置的下一张地图。并且修复了疑似由于map_changer导致的DisconnectToLobby错误
```sourcepawn
Action umDisconnectToLobby(...)
{
    UnhookUserMessage(g_umDisconnectToLobby, umDisconnectToLobby, true);
    g_bUMHooked = false;

    if (g_iFinaleChangeType & FINALE_CHANGE_CREDITS_END)
    {
        FinaleMapChange();
        return Plugin_Handled;
    }
}
```
它在处理第一条消息时就执行 UnhookUserMessage()，导致后续重复消息漏过去。

## 安装

将 `l4d2_keep_end_credits.smx` 放入服务器：

```text
left4dead2/addons/sourcemod/plugins/l4d2_keep_end_credits.smx
```

然后重启服务器或在服务器控制台执行：

```text
sm plugins load l4d2_keep_end_credits
```


## 验证

服务器控制台执行：

```text
sm plugins list
mapchanger_finale_change_type
```

后一个命令应显示值为 `8`。终局救援成功后会先播放统计字幕；字幕播放完，
或者玩家按空格完成跳过流程后，原 `map_changer` 插件再切换地图。

## 兼容性说明

- 投票插件仍通过 `MC_SetNextMap` 把玩家选择交给 `map_changer`，本补丁不会修改该流程。
- 自动换图插件原有的顺序、随机模式、自定义 `map_changer.cfg` 和失败次数设置均保持不变。
- 如果没有加载 `map_changer.smx`，本补丁不会做任何事；原版游戏流程也不会受影响。
- 本补丁启用期间，手动把 `mapchanger_finale_change_type` 改成其他值会被自动改回 `8`。

## 源码编译

仅依赖 SourceMod 自带的 `sourcemod.inc`：

```text
spcomp l4d2_keep_end_credits.sp
```
