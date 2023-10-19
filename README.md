# sdcs-testsuit
Simple test for SDCS

```sh
./sdcs-test.sh {cache_server_number}
```

## Todo
- [ ] More reasonable correctness tests (e.g., get those deleted keys explicitely.)
- [ ] Evaluate return value.
- [ ] Real performance test (by jmeter?)
- [ ] Better command line argument processing and help.

Mac用户运行脚本时若提示`shuf: command not found`，可以通过`brew install coreutils`安装相应的工具解决。
