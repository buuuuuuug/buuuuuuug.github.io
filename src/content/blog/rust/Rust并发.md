---
author: ChaneyChan
pubDatetime: 2025-07-17T15:22:00Z
modDatetime: 2025-07-17T15:22:00Z
title: Rust并发（一）- Rust并发基础
slug: rust-concurrency-basics
featured: true
draft: false
tags:
  - rust
  - 并发编程
  - 线程安全
  - Send
  - Sync
description: Rust并发编程基础 - 所有权、线程安全、Send与Sync特质详解
---

# Rust并发基础：所有权与线程安全

Rust的并发模型建立在所有权系统之上，这使得并发编程变得"无畏"（fearless）。本文将深入探讨Rust如何通过所有权系统和两个关键特质（Send和Sync）来保证线程安全。

## 1. 所有权：并发安全的基石

Rust的所有权系统是解决并发问题的核心机制。在任何时刻，每个值都有且仅有一个所有者，这从根本上防止了数据竞争。

### 所有权规则
- **单一所有权**：每个值在任意时刻只有一个所有者
- **移动语义**：值的所有权可以通过移动（move）转移
- **借用规则**：
  - 可以有多个不可变借用（`&T`）
  - 只能有一个可变借用（`&mut T`）
  - 不可变借用和可变借用不能同时存在

这些规则在编译时强制执行，使得数据竞争（两个可变别名同时存在）在编译阶段就无法通过。

```rust
// 示例：所有权如何在并发中保护数据
use std::thread;

fn main() {
    let data = vec![1, 2, 3];
    
    // 编译错误：data的所有权已经被移动
    // thread::spawn(|| {
    //     println!("{:?}", data);
    // });
    // println!("{:?}", data); // 错误：data已经被移动
    
    // 正确做法：使用Arc进行共享
    let data = std::sync::Arc::new(vec![1, 2, 3]);
    let data_clone = data.clone();
    
    let handle = thread::spawn(move || {
        println!("{:?}", data_clone);
    });
    
    handle.join().unwrap();
}
```

## 2. 线程安全的两个层面

在Rust中，线程安全包含两个层面：

1. **数据竞争自由**：通过所有权系统保证
2. **跨线程安全性**：通过`Send`和`Sync`特质保证

## 3. Send与Sync特质详解

### Send特质
`Send`标记一个类型可以安全地在线程间**转移**所有权。

```rust
// Send特质的定义
unsafe auto trait Send {}

// 实现示例
unsafe impl Send for MyType {}

// 实际应用
use std::thread;

fn transfer_ownership<T: Send + 'static>(data: T) {
    thread::spawn(move || {
        // 数据在这里被使用，所有权已转移到新线程
        println!("Processing: {:?}", data);
    });
}
```

**常见类型的Send实现：**
- 基本类型：`i32`, `String`, `Vec<T>`（当T: Send时）
- 原子类型：所有`std::sync::atomic`类型
- 智能指针：`Box<T>`（当T: Send时），`Arc<T>`（当T: Sync + Send时）

**非Send类型：**
- `Rc<T>`：引用计数不是线程安全的
- `*const T`和`*mut T`：原始指针

### Sync特质
`Sync`标记一个类型可以安全地在线程间**共享**不可变引用。

```rust
// Sync特质的定义
unsafe auto trait Sync {}

// 关键性质：T是Sync当且仅当&T是Send
// 即：&T: Send ⇒ T: Sync
```

**常见类型的Sync实现：**
- 不可变类型：大多数基本类型都是Sync
- 同步原语：`Mutex<T>`、`RwLock<T>`
- 原子类型：所有原子类型都是Sync

**非Sync类型：**
- `Cell<T>`：内部可变性，非线程安全
- `RefCell<T>`：运行时借用检查，非线程安全

### Send与Sync的关系

| 特质 | 作用 | 示例 |
|------|------|------|
| `Send` | 安全转移所有权到新线程 | `i32`, `String`, `Vec<T>` |
| `Sync` | 安全共享不可变引用 | `i32`, `Arc<T>`, `Mutex<T>` |
| `!Send` | 不能跨线程转移 | `Rc<T>`, `*const T` |
| `!Sync` | 不能跨线程共享引用 | `Cell<T>`, `RefCell<T>` |

## 4. 编译器如何使用Send和Sync

Rust编译器在以下场景自动检查Send和Sync约束：

### 线程创建
```rust
use std::thread;

fn spawn_thread<F, T>(f: F) -> thread::JoinHandle<T> 
where 
    F: FnOnce() -> T + Send + 'static,
    T: Send + 'static 
{
    thread::spawn(f)
}
```

### Arc的使用
```rust
use std::sync::Arc;

// Arc<T>要求T: Sync + Send
let data = Arc::new(42);
let data_clone = data.clone();

// 编译器检查：i32实现了Sync + Send
thread::spawn(move || {
    println!("Shared data: {}", data_clone);
});
```

## 5. 自定义类型的线程安全

当定义自己的类型时，编译器会自动推导Send和Sync实现：

```rust
// 自动实现Send和Sync，因为所有字段都是Send + Sync
#[derive(Debug)]
struct ThreadSafeData {
    value: i32,
    name: String,
}

// 需要显式标记为非Send/Sync
struct NotThreadSafe {
    rc: std::rc::Rc<i32>, // Rc不是Send/Sync
}

// 显式声明
impl !Send for NotThreadSafe {}
impl !Sync for NotThreadSafe {}
```

## 6. 实践指南

### 何时需要关注Send/Sync
1. **使用thread::spawn**时：确保闭包捕获的所有数据都是Send
2. **使用Arc共享数据**时：确保数据类型是Sync + Send
3. **实现自定义类型**时：检查是否包含非Send/Sync的字段

### 常见模式
```rust
use std::sync::{Arc, Mutex};
use std::thread;

// 安全共享可变状态
let counter = Arc::new(Mutex::new(0));
let mut handles = vec![];

for _ in 0..10 {
    let counter = Arc::clone(&counter);
    let handle = thread::spawn(move || {
        let mut num = counter.lock().unwrap();
        *num += 1;
    });
    handles.push(handle);
}

for handle in handles {
    handle.join().unwrap();
}

println!("Result: {}", *counter.lock().unwrap());
```

## 7. 小结

Rust通过以下机制构建安全的并发模型：

1. **所有权系统**：防止数据竞争
2. **Send特质**：保证值可以安全跨线程转移
3. **Sync特质**：保证引用可以安全跨线程共享
4. **编译时检查**：在编译阶段捕获线程安全问题

这种设计使得Rust能够在不牺牲性能的情况下，提供内存安全和线程安全的并发编程体验。

---

**下一篇预告**：我们将深入探讨Rust的原子操作和锁机制，包括`Mutex`、`RwLock`以及各种原子类型的使用。