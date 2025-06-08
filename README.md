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

## 简介

一个使用 [Flutter](https://flutter.dev/) 编写的跨平台音乐播放器应用。

本项目需要配合 [云舒 NAS](https://github.com/itning/yunshu-nas) 使用，作为后端音乐服务器，请自行搭建。

或者使用[云舒音乐本地服务端](https://github.com/itning/yunshu_music_local) 来使用

目前支持以下平台：

| 平台    | 支持 |
| ------- | ---- |
| Android | ✅   |
| Web     | ✅   |
| Windows | ✅   |
| MacOS   | ✅   |
| iOS     | ✅   |

> ⚠️ 暂不提供 Apple 平台的正式版本下载。

---

## 功能与开发进展

- **功能清单**：[功能计划](https://github.com/itning/yunshu_music/projects/1)
- **需求与反馈**：[Feature Issues](https://github.com/itning/yunshu_music/issues)
- **依赖库列表**：查看 [`pubspec.yaml`](https://github.com/itning/yunshu_music/blob/master/yunshu_music/pubspec.yaml#L29)

---

## 接口说明

### 获取歌曲列表接口

#### 响应示例（JSON）

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
      "type": 1, // 歌曲类型定义见下方链接
      "musicUri": "音乐URL路径，访问该URL即可拿到音乐数据",
      "lyricUri": "LRC歌词URL路径，访问该URL即可拿到歌词数据",
      "coverUri": "歌曲封面图片URL路径，访问该URL即可拿到歌曲封面图片数据",
      "musicDownloadUri": "音乐下载地址，可以和musicUri相同"
    },
    ...
  ]
}
```

#### 歌曲类型 `type` 定义

详见：[MusicType.java](https://github.com/itning/yunshu-nas/blob/master/nas-music/src/main/java/top/itning/yunshunas/music/constant/MusicType.java)

---

## 构建指南

### 本地构建依赖

- JDK 版本：17
- Flutter 版本：3.32.1

---

## 展示图

### 动图展示

<div align="center">
  <img width="200" height="400" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/a.gif"/>
  <img width="200" height="400" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/b.gif"/>
  <img width="200" height="400" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/c.gif"/>
</div>

### 静态图展示

<div align="center">
  <img width="150" height="300" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/a.jpg"/>
  <img width="150" height="300" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/b.jpg"/>
  <img width="150" height="300" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/c.jpg"/>
  <img width="150" height="300" src="https://raw.githubusercontent.com/itning/yunshu_music/master/pic/d.jpg"/>
</div>

---

## 项目统计信息

[![Repobeats Analytics](https://repobeats.axiom.co/api/embed/acce3f01122e88287589d77f79de75cd6eed7215.svg)](https://repobeats.axiom.co)

---

## 贡献与反馈

欢迎提交 Issue 或 Pull Request！  
GitHub 地址：[yunshu_music GitHub 仓库](https://github.com/itning/yunshu_music)
