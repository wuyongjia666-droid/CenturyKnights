# 百年骑士曲库许可

全部曲目由仓库内 `tools/audio/compose_v92.py` 以固定种子 `9202601` 程序化合成。
没有第三方采样、录音或曲库。编码为双声道 44.1 kHz Ogg Vorbis（libvorbis quality 1）。
金样校验比对解码后的 PCM 指纹（samples / rms_db / pcm_sha256），不要求 Ogg 容器逐字节一致。
Ogg 页序列号在合成后被改写为曲目种子，以去掉 ffmpeg 的随机序列号。

| 文件 | 用途 | 时长 | pcm_sha256 |
|---|---|---|---|
| `mus_title.ogg` | 主菜单 / 标题。霜灯动机的完整陈述。 | 75.8 s | `bbf642e58c02b9f9b9f53d351c787002717e592756baf7967766c6a56035edb0` |
| `mus_castle_spring.ogg` | 城堡·春生。内殿与工坊，按季节换调。 | 72.0 s | `2f286a3ecd7d321fd07ce888794f6a40ea4bcf31144c5727de90be166f9b6770` |
| `mus_castle_summer.ogg` | 城堡·夏澄。内殿与工坊，按季节换调。 | 72.0 s | `3ba0d7b81765fb45a051b6aefb09ade7aa34152bdb5bd5bcc9a30615813c026e` |
| `mus_castle_autumn.ogg` | 城堡·秋落。内殿与工坊，按季节换调。 | 72.0 s | `06d9de0829a22311ec78387efb0aeb5d9baf9c03e19bc9460b313461052244dd` |
| `mus_castle_winter.ogg` | 城堡·冬静。内殿与工坊，按季节换调。 | 72.0 s | `131919bee2231230b4dd47db5c5a44dfa5abc88f950759428d9737ee16ae2578` |
| `mus_atlas.ogg` | 舆图。陆桥上路的进行，霜灯动机作路标。 | 62.6 s | `44b73febc19f59c8e1a6be59cb23eb15f103e672cce092f708a000a400871a3f` |
| `mus_atlas_ashbanner.ogg` | 舆图·灰烬邦。同路不同国境的变奏。 | 62.6 s | `f09a7f9951983d5dca8907d8cf344a90a9c4f357963d7db063631efdea019b81` |
| `mus_atlas_shuoying.ogg` | 舆图·朔影国。同路不同国境的变奏。 | 62.6 s | `28aa41057eca80923a4bd05bea1d73ae17ab0e7864191a373f097f88df169dda` |
| `mus_atlas_qinghe.ogg` | 舆图·清河国。同路不同国境的变奏。 | 62.6 s | `3bf0d8e896a10894e074c551ef2361465d328f34b3797ed5f2487c0a95a02ae1` |
| `mus_atlas_lantern.ogg` | 舆图·灯市联。同路不同国境的变奏。 | 62.6 s | `3280e9f970be588310bf4f3a5dbf70e5fb6da6cba55e20dc2665a309a4e9078f` |
| `mus_atlas_frostcrown.ogg` | 舆图·霜冕廷。同路不同国境的变奏。 | 62.6 s | `a977455a5eba63193aa77b738cfe3c24dccfa4c83481c84756b18fab55a6c591` |
| `mus_atlas_emberold.ogg` | 舆图·余烬旧邦。同路不同国境的变奏。 | 62.6 s | `5634191c47989a9d8d25d8669ad937c756634c26fd503291751402a7cb77768c` |
| `mus_atlas_saltmarsh.ogg` | 舆图·盐泽盟。同路不同国境的变奏。 | 62.6 s | `4058b8dc596eb0fd798ce6db459afdf106a7d707d75284cd029169d84a8f003e` |
| `mus_atlas_irongorge.ogg` | 舆图·铁峡领。同路不同国境的变奏。 | 62.6 s | `311a0285ce4be45d54844509469f0d05efcb0043718a5ea03726f160ef555add` |
| `mus_atlas_starriver.ogg` | 舆图·星津邦。同路不同国境的变奏。 | 62.6 s | `d137fb668d10f7a5e5efc4466ea580bf9588ff911f5dd96320743a37c68d5ecf` |
| `mus_atlas_southzephyr.ogg` | 舆图·南泽邦。同路不同国境的变奏。 | 62.6 s | `755b8bafcfe6a72f4bb9783eba3482e0005132c1278ce31479d4925b9b164854` |
| `mus_battle_era1.ogg` | 纪元一·灯起。玩家回合，动机逐渐加密。 | 73.8 s | `c9ba49a873ad0c8b32ef4080caaff798b062b67bd43760880c00cf027e5e877f` |
| `mus_battle_era2.ogg` | 纪元二·霜盟。玩家回合，动机逐渐加密。 | 68.6 s | `bde34410e2a44448c74adb9af3c8a8f5685ee1cd3778f4e9f776a6b6f2e3bf22` |
| `mus_battle_era3.ogg` | 纪元三·裂桥。玩家回合，动机逐渐加密。 | 65.1 s | `424f84d36360b017afebf12e43f6cc33ddfa49775590314206135ff7d61ad265` |
| `mus_battle_era4.ogg` | 纪元四·冕战。玩家回合，动机逐渐加密。 | 64.0 s | `c81597bc8b8263f6d32711a1ead52fcbeebab8f8c04f82abd514af1fb6f21359` |
| `mus_battle_era5.ogg` | 纪元五·百年。玩家回合，动机逐渐加密。 | 64.0 s | `e7a847c301b6a99938738d096e0bbe7c5022c6463fd0f85ca0c03a8dc2b12e53` |
| `mus_battle_enemy.ogg` | 敌方回合。动机倒影，仍守 D 音踏板以便叠紧张层。 | 71.1 s | `a938bd102b48aec441e8ccaa51e6dad2fb99ed341e6a646d292a9f58accc3ba5` |
| `mus_battle_boss.ogg` | 首领。动机拉宽，低弦加倍，踏板不让路。 | 80.0 s | `f51c0dd32d143d8297483f8cd91923bf872786f009ff84fb29a2e2ab45aef23d` |
| `mus_tension.ogg` | 紧张。可单独播放的段落：悬置、抬升、回落，不是一条垫底循环。 | 72.0 s | `a14386c6cb5eb09363c867c12edbec76bc3c80162c3e3b4e938a2f22e740b6f9` |
| `mus_tension_layer.ogg` | 紧张层。D 踏板与四度进行，叠在战斗曲下，不另起满音量旋律。 | 68.6 s | `1c1616644012fbe24b5da980921a000f370a7a9f58b75f8b3ce455ad8262751f` |
| `mus_victory.ogg` | 胜利。动机转入大调，玻璃质感的上升，不作成套铜管号角。 | 64.0 s | `30f0099fa586af5dcb7b99dc04508eb7f0ea43fd6e4647cc462d08c0cc62dde5` |
| `mus_defeat.ogg` | 失败。动机拆成下行碎片，停在空五度。 | 80.0 s | `f160e1a21385eb40d9fdfb9e87dd9c9ca835efb21afdd7b1564dd12542f640ef` |
| `mus_marriage.ogg` | 联姻。动机以平行三度成对出现。 | 68.6 s | `20b6287cb6b780a660df8ec78e183650a8b2c2ba8327f5b98b738507540e75fd` |
| `mus_funeral.ogg` | 葬礼 / 先祖。动机拉成宽音，高玻璃铃回应低弦。 | 64.0 s | `9e3002d195052f51ff0f0abae2c96ef5c5f4294c80a36db4584498b4120e1fa7` |
| `mus_birth.ogg` | 初啼。高音区的摇篮式动机，春令的颜色。 | 75.8 s | `38eb2627973d6ae050bb994229bfa3a3a072906c8e3d8590cf0f2985231f0925` |
| `mus_inheritance.ogg` | 继承。动机先在低音陈述，再交到高音。 | 80.0 s | `6bee2bc6a64dad595d787d0427b8021c43ee2a5e47ce2bce07aa22d9ecb9b95b` |
| `mus_city_ashbanner.ogg` | 城市·灰烬邦。十国城市变奏，城内比路上更稳。 | 73.8 s | `6de33aa7bcc4cf6f3a9d132513514cf6a05faf85a1191eb1c3fa80574f941ff2` |
| `mus_city_shuoying.ogg` | 城市·朔影国。十国城市变奏，城内比路上更稳。 | 73.8 s | `e74501e0c0bd34ca1a877da750644f7b47031b6010f72450dcb5d282925eff61` |
| `mus_city_qinghe.ogg` | 城市·清河国。十国城市变奏，城内比路上更稳。 | 73.8 s | `bed0803b98fb6f3848fc30fafd06948645b89810a5eebaa7bd216d52dcb80c61` |
| `mus_city_lantern.ogg` | 城市·灯市联。十国城市变奏，城内比路上更稳。 | 73.8 s | `2777fa36a3936bb7d5a9826dfcfa9ec312788813bf99c1d082a0c864d7a5d568` |
| `mus_city_frostcrown.ogg` | 城市·霜冕廷。十国城市变奏，城内比路上更稳。 | 73.8 s | `ea7fe4a3dbc12ca8ea8a93f5995f3ca9c4f79e7004a1e08dd92bd6bbcb2673ae` |
| `mus_city_emberold.ogg` | 城市·余烬旧邦。十国城市变奏，城内比路上更稳。 | 73.8 s | `ac260e14251bc52dc52a9846312b74d01822195387651e40870559c9e768ed9c` |
| `mus_city_saltmarsh.ogg` | 城市·盐泽盟。十国城市变奏，城内比路上更稳。 | 73.8 s | `394d7dda44280e30d406b504f1f147c60d7e38d694685435e6e16162fdc4f62d` |
| `mus_city_irongorge.ogg` | 城市·铁峡领。十国城市变奏，城内比路上更稳。 | 73.8 s | `06de838d1a123c81f356318acbdd822a4004e17e1a5037924400035f99a178ab` |
| `mus_city_starriver.ogg` | 城市·星津邦。十国城市变奏，城内比路上更稳。 | 73.8 s | `2bcc1a0f74ca91b049abd8f31498471c1603054109a09708a32b231c5a5ffb55` |
| `mus_city_southzephyr.ogg` | 城市·南泽邦。十国城市变奏，城内比路上更稳。 | 73.8 s | `51243b26848baf23715bd73ea31b0e49d94b98cafedbe74c7b7d1d96e8e0e9c7` |

汇总体积：15374141 字节（14.66 MiB）。
