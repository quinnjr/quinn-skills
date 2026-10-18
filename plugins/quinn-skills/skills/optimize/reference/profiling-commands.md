# Profiling Commands Reference

Canonical commands for dynamic-mode profiling, one section per stack.
The `runtime` and `memory` agents pick from this list based on the
detected manifest, then **always ask the user for confirmation before
executing**. Pick the lowest-friction option available for the stack.

## Node.js / TypeScript

### CPU profile — built-in V8 profiler (no deps)
```
node --prof --prof-process-only <script-or-test-runner>
```

For a test target:
```
node --prof $(which jest) --runInBand --testPathPattern=<path>
node --prof $(which vitest) run
```

Then process the `isolate-*.log`:
```
node --prof-process isolate-*.log > profile.txt
```

### CPU profile — `clinic`
```
npx clinic doctor -- node <script>
npx clinic flame  -- node <script>
```

### Heap snapshot
```
node --inspect --expose-gc <script>
```
Then use `node --inspect-brk` with `chrome://inspect` or
`--heapsnapshot-signal=SIGUSR2`.

### Allocation profile — `clinic heapprofiler`
```
npx clinic heapprofiler -- node <script>
```

## Python

### CPU profile — `py-spy` (no source changes, works on running process)
```
py-spy record -o profile.svg -- python -m pytest <path>
py-spy record -o profile.svg -- python <script>
```

### CPU profile — `cProfile` (stdlib)
```
python -m cProfile -o profile.out -m pytest <path>
python -m pstats profile.out
```

### Memory profile — `memray`
```
memray run -o profile.bin -m pytest <path>
memray stats profile.bin
memray flamegraph profile.bin
```

### Memory profile — `tracemalloc` (stdlib, in-code)
```
python -X tracemalloc=10 <script>
```

## Rust

### CPU profile — `cargo flamegraph`
```
cargo flamegraph --bench <bench-name>
cargo flamegraph --test <test-name>
```

### CPU profile — `perf` (Linux)
```
cargo build --release
perf record --call-graph=dwarf target/release/<binary>
perf report
```

### Memory / allocation — `dhat-rs`
Requires `dhat` feature + code wiring; suggest adding as a one-off.

### Memory — `heaptrack`
```
cargo build --release
heaptrack target/release/<binary>
heaptrack_gui heaptrack.*.gz
```

## Go

### CPU profile
```
go test -cpuprofile=cpu.prof -bench=. <package>
go tool pprof cpu.prof
```

### Memory profile
```
go test -memprofile=mem.prof -bench=. <package>
go tool pprof mem.prof
```

### Live profile via HTTP
Requires `_ "net/http/pprof"` import. Then:
```
go tool pprof http://localhost:<port>/debug/pprof/profile?seconds=30
go tool pprof http://localhost:<port>/debug/pprof/heap
```

## JVM (Java / Kotlin / Scala)

### CPU — `async-profiler`
```
asprof -d 30 -f profile.html <pid>
```

### Allocation profile
```
asprof -e alloc -d 30 -f alloc.html <pid>
```

### Heap dump
```
jmap -dump:live,format=b,file=heap.hprof <pid>
```

## Ruby

### CPU — `rbspy`
```
rbspy record --file profile.svg -- bundle exec rspec
```

### Memory — `memory_profiler`
```
ruby -r memory_profiler -e "MemoryProfiler.report { load '<script>' }.pretty_print"
```

## Selection Rules for Agents

1. Prefer a profiler that:
   - Does not require source-code changes
   - Has a simple one-shot command
   - Runs against the existing test / benchmark target

2. If multiple options fit, prefer (in order): `py-spy`, `clinic`,
   `cargo flamegraph`, `go test -cpuprofile`, `async-profiler`,
   `rbspy`. Avoid instrumenting the source unless no external
   profiler is available.

3. If the project has no test or benchmark target, say so rather than
   guessing; the orchestrator will ask the user for an entry-point command.

4. Never execute a profiler without the user's explicit approval of the
   exact command. Agents only propose it; the orchestrator asks the user
   and runs it.

5. If the command takes longer than a couple of minutes to run, say so in
   the proposal so the user sees it in the confirmation prompt.

6. If the command fails (missing tool, broken build, etc.), fall back
   to static-only analysis and note the fallback reason in the report.
