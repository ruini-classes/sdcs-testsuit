<!--
 * @Author: ringfall linfp21@126.com
 * @LastEditTime: 2023-10-06 13:01:57
 * @Description: 
 * 
 * Copyright (c) 2023 by Peng-LinFeng, All Rights Reserved. 
-->
# sdcs-testsuit
Simple test for SDCS

```sh
./sdcs-test.sh {cache_server_number}
```

## Todo
- [ ] More reasonable correctness tests (e.g., get those deleted keys explicitely.)
- [x] Evaluate return value.
- [ ] Real performance test (by jmeter?)
- [ ] Better command line argument processing and help.

## Q&A
- Mac用户运行脚本时若提示`shuf: command not found`，可以通过`brew install coreutils`安装相应的工具解决。
