<h3 align="center">云舒音乐</h3>
<div align="center">

[![GitHub stars](https://img.shields.io/github/stars/itning/yunshu_music.svg?style=social&label=Stars)](https://github.com/itning/yunshu_music/stargazers)
[![GitHub forks](https://img.shields.io/github/forks/itning/yunshu_music.svg?style=social&label=Fork)](https://github.com/itning/yunshu_music/network/members)
[![GitHub watchers](https://img.shields.io/github/watchers/itning/yunshu_music.svg?style=social&label=Watch)](https://github.com/itning/yunshu_music/watchers)
[![GitHub followers](https://img.shields.io/github/followers/itning.svg?style=social&label=Follow)](https://github.com/itning?tab=followers)


</div>

<div align="center">

[![GitHub issues](https://img.shields.io/github/issues/itning/yunshu_music.svg)](https://github.com/itning/yunshu_music/issues)
[![GitHub license](https://img.shields.io/github/license/itning/yunshu_music.svg)](https://github.com/itning/yunshu_music/blob/master/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/itning/yunshu_music.svg)](https://github.com/itning/yunshu_music/commits)
[![GitHub repo size in bytes](https://img.shields.io/github/repo-size/itning/yunshu_music.svg)](https://github.com/itning/yunshu_music)
[![Hits](https://hitcount.itning.com?u=itning&r=yunshu_music)](https://github.com/itning/hit-count)
[![language](https://img.shields.io/badge/language-Dart-green.svg)](https://github.com/itning/yunshu_music)

</div>

一个使用flutter编写的跨平台音乐播放app

[配合云舒NAS作为后端音乐服务器，请自行搭建](https://github.com/itning/yunshu-nas)

目前支持平台：

| 平台    | 支持 |
| ------- | ---- |
| Android | √    |
| Web     | √    |
| Windows | √    |
| MacOS   | √    |
| IOS     | √    |

暂不提供apple platform release版本下载

功能清单：[功能计划](https://github.com/itning/yunshu_music/projects/1)

需求列表：[feat](https://github.com/itning/yunshu_music/issues)

依赖库：[dependencies](https://github.com/itning/yunshu_music/blob/master/yunshu_music/pubspec.yaml#L29)

获取歌曲列表接口：

其中歌曲类型`type`定义可以[在这里](https://github.com/itning/yunshu-nas/blob/master/nas-music/src/main/java/top/itning/yunshunas/music/constant/MusicType.java)找到

```json
{
    "code": 200,
    "msg": "查询成功",
    "data": [
            {
                "musicId": "音乐ID，不可重复",
                "name": "音乐名称",
                "singer": "歌手名",
                "lyricId": "歌词ID，可以和音乐ID相同",
                "type": 1, // 歌曲类型
                "musicUri": "音乐URL路径，访问该URL即可拿到音乐数据",
                "lyricUri": "LRC歌词URL路径，访问该URL即可拿到歌词数据",
                "coverUri": "歌曲封面图片URL路径，访问该URL即可拿到歌曲封面图片数据"
            },
            ...
        ]
}
```



<div  align="center">
<img width="200" height="400" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/a.gif"/> 
<img width="200" height="400" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/b.gif"/> 
<img width="200" height="400" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/c.gif"/>
</div>

<div  align="center">
<img width="150" height="300" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/a.jpg"/> 
<img width="150" height="300" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/b.jpg"/> 
<img width="150" height="300" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/c.jpg"/>
<img width="150" height="300" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/d.jpg"/>
</div>

![Alt](https://repobeats.axiom.co/api/embed/acce3f01122e88287589d77f79de75cd6eed7215.svg "Repobeats analytics image")
