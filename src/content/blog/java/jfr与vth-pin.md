---
author: ChaneyChan
pubDatetime: 2024-06-14T15:22:00Z
modDatetime: 2023-06-11T09:12:47.400Z
title: JFR 介绍与基本使用
slug: jfr-event
featured: true
draft: false
tags:
  - java
  - 可观测性
  - 虚拟线程
  - jfr
description: 尝试使用jfr对java应用进行监控，主要为了在native-image模式下，缺少jvm、gc、vth监控指标情况下，补充可观测性指标
---

## Table of contents

本文会尝试从一下几个方面进行组织：

1. jfr介绍（为什么需要jfr）
2. jfr的常规使用（jar包部署模式 ｜ 使用jcmd导出.jfr文件）
3. 利用JFR排查CPU飙升
4. 利用JFR排查OOM问题
5. 利用JFR排查与监控虚拟线程的pin事件
6. event-stream介绍与简单使用
7. JFR的优势与局限性
8. 服务监控矩阵

## jfr介绍

jfr全称`java-flight-recorder`，飞行记录仪，是在jdk11中开源的一个性能监控组件。它提供了一个低开销的java应用、jvm和操作系统的事件监控框架。
可执行文件 `jfr`内置与jdk中。
如同飞机上的黑匣子，在java应用运行过程中，它时时刻刻都在记录中多种多样的事件，详细的事件列表可以参考 [jfr事件列表](https://sap.github.io/SapMachine/jfrevents/21.html?variant=graal&version=8#introduction)

## jfr的常规使用与分析

这部分我会介绍如何快速开启jfr，分别针对传统jar包部署和native模式。

### jar包部署下：

1.  采集jfr

    通常当我们使用 `java -jar` 命令运行一个jar包后，可以通过 `jps` 命令查看系统中当前的java进程有哪些，从中我们可以找到刚刚启动的jar包进程
    ![java-jar-jps](../../../assets/images/java-jar-jps.png)
    在本次实验中进程为`2859`，然后我们就可以通过 `jcmd`命令开启jfr

    ```shell
    jcmd 2859 JFR.start

    jcmd 2859 JFR.dump
    ```

    ![jcmd-start-dump](../../../assets/images/jcmd-start-dump.png)
    现在我们就得到了一个 `recording.jfr` 文件，这个文件就是在我们刚刚采集事件期间，java应用程序、jvm、操作系统中发生的绝大多数事件。

2.  查看jfr文件

    jfr文件二进制编码文件，需要使用专门的解析工具查看。
    当然可以先通过 jfr命令初步查看

    ```shell
      jfr summary recording.jfr
    ```

    ![jfr-summary](../../../assets/images/jfr-summary.png)

    这个命令可以快速告诉我们这个jfr文件中记录的事件分布。
    但是为了更加详细地了解其中的jfr事件，我们需要用到一个工具`jmc`.这个软件是独立于jdk提供的，类似visualVM。下载地址 [jmc](https://www.oracle.com/java/technologies/javase/products-jmc8-downloads.html)

    ![jmc](../../../assets/images/jmc.png)
    运行jmc即可，将刚刚得到的jfr文件导入，在事件浏览器一栏，可以看到采集到的各种事件

    ![jmc-ui](../../../assets/images/jmc-ui.png)

### native-image部署模式下

在native-iamge模式下，jfr仍然可以使用，但是由于启用的java应用进程不再能被jps命令指出，也就是说，我们不能通过jcmd命令控制应用程序开始采集与结束采集jfr事件。

所以，一个可行的方案是，在运行时就开启jfr记录，通过指定max-age 和 max-size的方式控制内存和硬盘占用，当需要导出指定时间段的事件时，通过命令裁剪出所需的数据。

当前 graalvm jdk21，编译时需要加上 参数 `--enable-monitoring=jfr`, 启动时需要加上参数 `-XX:StartFlightRecording="filename=recording.jfr,settings=default.jfc,maxage=1d,maxsize=1G"`

## JFR 排查CPU飙升

CPU

- thread cpu load: per thread cpu occupy
- thread dump: thread dump info

## JFR排查OOM

这里不会去罗列所有支持的内存 相关事件，我们通过一个示例看一下JFR面对OOM会发生哪些值得关注的事件。

- AllocationRequiringGC： 这个事件记录了一次导致gc的内存分配事件。
- OldObjectSample 采样并记录老年代（Old Generation）中的对象信息
- g1 young garbage collection gc young-gen gc events
- garbage collection all gc events
- old garbage collection old-gen gc events

## 利用JFR排查虚拟线程的pin事件

虚拟线程在简化了异步任务开发模式和提高吞吐的情况下，目前也还存在一些问题，其中 可能影响较大的当属 `pin` 事件。单个虚拟线程的pin状态不足以影响h整个系统的运行（<u>pin住一个载体线程，调度线程池就需要额外创建一个载体线程，由于没有池化，大量创建载体线程甚至会使系统响应不足不适用虚拟线程的情况</u>）但是虚拟线程的事件往往都不会是 孤立的。

所以我认为，对虚拟线程有必要监控 pin 事件。JFR中就有专门记录这个状态的事件， `jdk.VirtualThreadPinned` 事件。

最简单的使虚拟线程陷入 pin 状态的代码为：

```java
//syncornized + park / wait

Thread.ofVirtual()
                .name("web-vt-" + UUID.randomUUID())
                .start(() -> {
                    synchronized (this) {
                        log.info("Causing thread pinning for example purposes");
                        sleep(Duration.ofMillis(250));
                    }
                    cdl.countDown();
                });
```

目前一些观点认为虚拟线程不适合上生产环境，主要的考虑在于 pin 线程会严重影响性能，而且目前很多框架都还没有实现虚拟线程适配。[common-pool-loom-adaptive](https://github.com/apache/commons-pool/pull/230/files)

## event-stream以及接入grafana

按需开启JFR固然有他灵活的优势，但是对于问题排查而言，他需要问题发生现场开启，这一点几乎是不可能的，不仅仅在于人不能及时响应，现场也不一定能始终保持。而且，鉴于JFR的默认配置几乎不影响系统性能，可以考虑将JFR事件转为Prometheus的指标，从而实现在grafana中实时监控。

```java
@Component
class JfrEventLifecycle implements SmartLifecycle {

    private final AtomicBoolean running = new AtomicBoolean(false);

    private final JfrVirtualThreadPinnedEventHandler virtualThreadPinnedEventHandler;

    private RecordingStream recordingStream;

    JfrEventLifecycle(JfrVirtualThreadPinnedEventHandler virtualThreadPinnedEventHandler) {
        this.virtualThreadPinnedEventHandler = virtualThreadPinnedEventHandler;
    }

    @Override
    public void start() {
        if (!isRunning()) {
            recordingStream = new RecordingStream();

            recordingStream.enable("jdk.VirtualThreadPinned").withStackTrace();
            recordingStream.onEvent("jdk.VirtualThreadPinned", virtualThreadPinnedEventHandler::handle);

            // prevents memory leaks in long-running apps
//            recordingStream.setMaxAge(Duration.ofSeconds(10));

            recordingStream.startAsync();
            running.set(true);
        }
    }

    @Override
    public void stop() {
        if (isRunning()) {
            recordingStream.close();
            running.set(false);
        }
    }

    @Override
    public boolean isRunning() {
        return running.get();
    }

}

void handle(RecordedEvent event) {
        // marked as nullable in Javadoc
        var thread = event.getThread() != null ? event.getThread().getJavaName() : "<unknown>";
        var duration = event.getDuration();
        var startTime = LocalDateTime.ofInstant(event.getStartTime(), ZoneId.systemDefault());
        var stackTrace = formatStackTrace(event.getStackTrace());

        log.info(
                "Thread '{}' pinned for: {}ms at {}, stacktrace: \n{}",
                thread,
                duration.toMillis(),
                startTime,
                stackTrace
        );

        var timer = meterRegistry.timer("jfr.thread.pinning");
        timer.record(duration);

```

## JFR的优势与局限性

### 优势

- 在线监控：采集监控数据不需要认为介入。对比arthas需要问题发生时介入。
- 低资源消耗：default配置几乎没有消耗
- 现场回溯 历史事件保存在JFR文件中，可以随时回溯。
- 快速：dump JFR文件只需几秒钟，dump堆得半个小时起步。

### 局限性

- 提供的信息有限
- 依赖额外的文件持久化支持

## 参考资料

- [JFR 全解](https://www.zhihu.com/column/c_1264859821121355776)
- [JFR events](https://sap.github.io/SapMachine/jfrevents/21.html?variant=graal&version=8#introduction)
- [graalvm native-image-jfr](https://www.graalvm.org/dev/reference-manual/native-image/debugging-and-diagnostics/JFR/)
- [native image jfr support issue](https://github.com/oracle/graal/issues/5410)
