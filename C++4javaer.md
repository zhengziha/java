# C++与Java对比指南

## 目录

- [零、C++资源推荐](#零c资源推荐)
- [一、关于Java](#一关于java)
- [二、关于C++](#二关于c)
- [三、C++和Java微观对比](#三c和java微观对比)
  - [1. C++编译和Java的虚拟机对比](#1-c编译和java的虚拟机对比)
  - [2. C++的开发环境搭建](#2-c的开发环境搭建)
  - [3. C++与Java的文件结构对比](#3-c与java的文件结构对比)
  - [4. C++与Java的集成开发环境](#4-c与java的集成开发环境)
  - [5. C++和Java常用库的对比](#5-c和java常用库的对比)
  - [6. C++的基础数据类型和Java的基础数据类型对比](#6-c的基础数据类型和java的基础数据类型对比)
  - [7. C++和Java的变量对比](#7-c和java的变量对比)
  - [8. C++和Java的常量对比](#8-c和java的常量对比)
  - [9. C++与Java的赋值对比](#9-c与java的赋值对比)
  - [10. C++与Java的注释](#10-c与java的注释)
  - [11. C++和Java的访问权限设置区别](#11-c和java的访问权限设置区别)
  - [12. C++与Java程序文件的后缀名对比](#12-c与java程序文件的后缀名对比)
  - [13. C++与Java选择结构的对比](#13-c与java选择结构的对比)
  - [14. C++与Java循环结构的对比](#14-c与java循环结构的对比)
  - [15. C++与Java的数组对比](#15-c与java的数组对比)
  - [16. C++的指针和引用与Java的引用类型对比](#16-c的指针和引用与java的引用类型对比)
  - [17. C++中的内存管理与Java的垃圾回收对比](#17-c中的内存管理与java的垃圾回收对比)
  - [18. C++相关的数据容器和Java的集合框架对比](#18-c相关的数据容器和java的集合框架对比)
  - [19. C++中的函数和Java中的方法对比](#19-c中的函数和java中的方法对比)
  - [20. C++的命名空间和Java的包机制对比](#20-c的命名空间和java的包机制对比)
  - [21. C++的标准输出库iostream和Java的输出打印库对比](#21-c的标准输出库iostream和java的输出打印库对比)
  - [22. C++的面向对象相关知识](#22-c的面向对象相关知识)
  - [23. C++中多线程的实现和Java语言中线程的实现](#23-c中多线程的实现和java语言中线程的实现)
  - [24. C++中的模板与Java中的泛型对比](#24-c中的模板与java中的泛型对比)
  - [25. 变量作用域和生命周期](#25-变量作用域和生命周期)
  - [26. C++和Java字符串操作的区别](#26-c和java字符串操作的区别)
  - [27. C++和Java的IO操作的区别](#27-c和java的io操作的区别)
  - [28. C++中的Lambda表达式和函数式编程与Java对比](#28-c中的lambda表达式和函数式编程与java对比)
  - [29. C++中的map和Java中的HashMap](#29-c中的map和java中的hashmap)
  - [30. C++中的时间和日期处理与Java的Time API对比](#30-c中的时间和日期处理与java的time-api对比)
  - [31. C++和Java关于网络编程的对比](#31-c和java关于网络编程的对比)
  - [32. C++如何连接数据库](#32-c如何连接数据库)
  - [33. C++中的依赖管理工具对比](#33-c中的依赖管理工具对比)
  - [34. C++的并发编程与Java的区别](#34-c的并发编程与java的区别)
  - [35. C++的性能优化和Java的性能优化](#35-c的性能优化和java的性能优化)
  - [36. C++的测试框架与Java的单元测试](#36-c的测试框架与java的单元测试)
  - [37. C++的类型推导与Java的var关键字](#37-c的类型推导与java的var关键字)
  - [38. C++的异常处理与Java的异常处理对比](#38-c的异常处理与java的异常处理对比)
  - [39. C++的函数重载与Java的方法重载](#39-c的函数重载与java的方法重载)
  - [40. C++的运算符重载与Java的对比](#40-c的运算符重载与java的对比)
  - [41. C++的友元与Java的对比](#41-c的友元与java的对比)
  - [42. C++的虚函数与多态与Java的对比](#42-c的虚函数与多态与java的对比)
  - [43. C++的RAII与Java的try-with-resources对比](#43-c的raii与javatry-with-resources对比)
  - [44. C++的移动语义与Java的对比](#44-c的移动语义与java的对比)
  - [45. C++的智能指针与Java的对比](#45-c的智能指针与java的对比)
  - [46. C++的预处理指令与Java的注解对比](#46-c的预处理指令与java的注解对比)
- [四、C++最佳实践和常见陷阱](#四c最佳实践和常见陷阱)

---

## 零、C++资源推荐

### 官方资源

- **C++官方标准**：https://en.cppreference.com/w/
- **C++中文文档**：https://zh.cppreference.com/w/
- **C++官方编译器**：https://gcc.gnu.org/ (GCC)、https://visualstudio.microsoft.com/ (MSVC)

### 学习资源

- **《C++ Primer》** - 经典入门教材
- **《Effective C++》** - Scott Meyers著，进阶必读
- **《Modern Effective C++》** - C++11/14现代特性
- **LearnCpp.com** - 在线教程
- **Compiler Explorer** - https://godbolt.org/ 在线编译查看汇编代码

---

## 一、关于Java

### 1. Java的用途

首先我们来回顾下Java的主要用途和应用场景：

#### 用途一：服务器后端系统开发
Web后端、微服务后端、支付系统、业务系统、管理后台，各种后台交互的接口服务。

#### 用途二：大数据框架的底层实现和Java的API支持
例如：Hadoop、Spark、Flink

#### 用途三：企业级应用开发
各种企业级应用、Android应用开发、中间件开发

### 2. Java的优势和特点

那么我们看Java语言有什么优势和特点呢？

- ✅ **跨平台**：一次编写，到处运行
- ✅ **自动内存管理**：垃圾回收机制
- ✅ **丰富的生态系统**：海量的类库和框架
- ✅ **强类型安全**：编译时类型检查
- ✅ **面向对象**：完整的OOP支持
- ✅ **多线程支持**：内置并发机制
- ✅ **市场占有率高**：企业级开发首选语言之一

---

## 二、关于C++

### 1. C++的用途

C++是一种多范式编程语言，用途非常广泛：

#### 用途一：系统级编程
操作系统、驱动程序、嵌入式系统、游戏引擎

#### 用途二：高性能应用
高频交易系统、实时控制系统、科学计算、图形渲染

#### 用途三：应用软件开发
办公软件、浏览器、数据库系统、大型游戏

#### 用途四：基础设施
网络服务器、云计算平台、大数据处理

### 2. C++的优势和特点

- ✅ **极致性能**：无虚拟机开销，直接编译为机器码
- ✅ **底层控制**：直接内存访问，硬件级别控制
- ✅ **多范式编程**：支持面向对象、泛型、函数式编程
- ✅ **零开销抽象**：现代C++的抽象不带来运行时成本
- ✅ **跨平台**：支持几乎所有平台和架构
- ✅ **向后兼容**：C++代码可以运行C代码
- ✅ **标准库丰富**：STL提供强大的数据结构和算法
- ✅ **编译时计算**：模板元编程实现编译时计算

### 3. C++的历史和版本

| 版本    | 发布时间 | 重要特性                       |
| ----- | ---- | -------------------------- |
| C++98 | 1998 | 第一个ISO标准                   |
| C++03 | 2003 | 修复bug的技术修正                 |
| C++11 | 2011 | 重大更新：智能指针、lambda、auto、右值引用 |
| C++14 | 2014 | 小幅改进：泛型lambda、函数返回类型推导     |
| C++17 | 2017 | 结构化绑定、if constexpr、fold表达式 |
| C++20 | 2020 | 概念、范围、协程、模块                |
| C++23 | 2023 | 更多改进和新特性                   |

**建议**：现代C++开发建议使用C++17或更高版本。

---

## 三、C++和Java微观对比

### 1. C++编译和Java的虚拟机对比

#### Java的运行机制

```
Java源代码(.java) → 编译器 → 字节码(.class) → JVM → 机器码执行
```

Java代码首先被编译成字节码，然后在Java虚拟机(JVM)上运行。JVM提供了：

- 内存管理和垃圾回收
- 平台无关性
- 安全性检查
- 即时编译(JIT)优化

#### C++的编译机制

```
C++源代码(.cpp) → 编译器 → 目标文件(.o/.obj) → 链接器 → 可执行文件
```

C++代码直接编译为机器码，包含以下过程：

1. **预处理**：处理#include、#define等指令
2. **编译**：将源代码编译为汇编代码
3. **汇编**：汇编代码转为机器码
4. **链接**：将多个目标文件链接成可执行文件

#### 主要区别

| 特性 | C++ | Java |
|------|-----|------|
| 编译结果 | 机器码 | 字节码 |
| 运行环境 | 操作系统 | JVM |
| 启动速度 | 快 | 慢(需要JVM启动) |
| 内存管理 | 手动/智能指针 | 垃圾回收 |
| 性能 | 高 | 中等(JIT优化后) |
| 平台相关 | 需重新编译 | 跨平台 |

### 2. C++的开发环境搭建

#### Linux环境

```bash
# 安装GCC编译器
sudo apt-get install build-essential

# 安装CMake构建工具
sudo apt-get install cmake

# 安装调试器
sudo apt-get install gdb

# 安装IDE推荐
# VS Code + C/C++扩展
# CLion (付费)
```

#### Windows环境

**推荐方案一：Visual Studio**
1. 下载Visual Studio Community (免费)
2. 安装时选择"使用C++的桌面开发"
3. 内置MSVC编译器和调试器

**推荐方案二：MinGW**
```bash
# 安装MSYS2
# https://www.msys2.org/
# 在MSYS2中安装MinGW工具链
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake
```

#### macOS环境

```bash
# 安装Xcode命令行工具
xcode-select --install

# 使用Homebrew安装开发工具
brew install gcc cmake gdb

# 或者直接安装Xcode获得完整的IDE
```

### 3. C++与Java的文件结构对比

#### Java的文件结构

```
Project/
├── src/
│   ├── main/
│   │   └── java/
│   │       └── com/
│   │           └── example/
│   │               └── Main.java
│   └── test/
│       └── java/
│           └── com/
│               └── example/
│                   └── MainTest.java
├── pom.xml (Maven配置)
└── target/ (编译输出)
```

#### C++的文件结构

```
Project/
├── include/           # 头文件
│   └── myclass.h
├── src/              # 源文件
│   └── myclass.cpp
├── tests/            # 测试文件
│   └── test_myclass.cpp
├── CMakeLists.txt    # CMake构建配置
├── build/            # 编译输出目录
└── bin/              # 可执行文件
```

#### 头文件和源文件分离

C++传统上将声明放在头文件(.h)，实现放在源文件(.cpp)：

```cpp
// myclass.h - 头文件
#ifndef MYCLASS_H
#define MYCLASS_H

class MyClass {
public:
    void sayHello();
    int add(int a, int b);
};

#endif

// myclass.cpp - 源文件
#include "myclass.h"
#include <iostream>

void MyClass::sayHello() {
    std::cout << "Hello from MyClass!" << std::endl;
}

int MyClass::add(int a, int b) {
    return a + b;
}
```

### 4. C++与Java的集成开发环境

#### Visual Studio (Windows)

**优点**：
- 完美的Windows集成
- 强大的调试器
- IntelliSense代码提示
- 内置性能分析工具

**缺点**：
- 仅支持Windows
- 安装包较大

#### CLion (跨平台)

**优点**：
- 跨平台支持
- 基于IntelliJ平台
- 强大的CMake支持
- 内置现代C++支持

**缺点**：
- 付费软件(学生免费)

#### VS Code (跨平台)

**优点**：
- 免费开源
- 轻量级
- 丰富的扩展生态
- 支持远程开发

**缺点**：
- 需要配置更多扩展
- 调试体验不如专业IDE

#### Eclipse CDT (跨平台)

**优点**：
- 免费开源
- 功能全面
- 插件生态丰富

**缺点**：
- 界面相对老旧
- 配置较为复杂

### 5. C++和Java常用库的对比

| Java | C++ | 用途 |
|------|-----|------|
| java.util | STL | 集合框架和算法 |
| java.io | fstream/iostream | 文件IO |
| java.net | Boost.Asio/POSIX socket | 网络编程 |
| java.sql | JDBC驱动 | 数据库连接 |
| java.util.concurrent | std::thread/std::mutex | 并发编程 |
| java.time | std::chrono | 时间处理 |
| java.math | boost multiprecision | 大数运算 |
| Apache Commons | Boost | 通用工具库 |
| Jackson/ Gson | nlohmann json | JSON处理 |
| Log4j | spdlog/log4cpp | 日志框架 |

### 6. C++的基础数据类型和Java的基础数据类型对比

#### 整数类型对比

| Java | C++ | 字节数 | 范围 |
|------|-----|--------|------|
| byte | int8_t/signed char | 1 | -128 到 127 |
| short | int16_t/short | 2 | -32,768 到 32,767 |
| int | int32_t/int | 4 | -2³¹ 到 2³¹-1 |
| long | int64_t/long long | 8 | -2⁶³ 到 2⁶³-1 |
| - | size_t | 平台相关 | 无符号整数类型 |

#### 浮点类型对比

| Java | C++ | 字节数 | 精度 |
|------|-----|--------|------|
| float | float | 4 | 单精度浮点数 |
| double | double | 8 | 双精度浮点数 |
| - | long double | 16+ | 扩展精度(平台相关) |

#### 字符类型对比

| Java | C++ | 字节数 | 说明 |
|------|-----|--------|------|
| char | char | 1 | ASCII字符 |
| - | wchar_t | 2/4 | 宽字符 |
| - | char8_t | 1 | UTF-8字符(C++20) |
| - | char16_t | 2 | UTF-16字符 |
| - | char32_t | 4 | UTF-32字符 |

#### 布尔类型

```cpp
// Java
boolean flag = true;

// C++
bool flag = true;
```

#### C++特有的类型

```cpp
// 指针类型
int* ptr;
int** ptrToPtr;

// 引用类型
int& ref = variable;

// 枚举类型
enum Color { RED, GREEN, BLUE };

// auto类型推导(C++11)
auto number = 42; // 推导为int

// nullptr(C++11)
int* ptr = nullptr; // 替代NULL
```

### 7. C++和Java的变量对比

#### 变量声明

```cpp
// Java
int age = 25;
String name = "John";
boolean isActive = true;

// C++
int age = 25;
std::string name = "John";
bool isActive = true;
```

#### 变量初始化

```cpp
// Java - 基本类型有默认值
int num; // 默认0
boolean flag; // 默认false

// C++ - 局部变量必须初始化
int num = 0; // 必须显式初始化
bool flag = false; // 必须显式初始化

// C++11 统一初始化语法
int num{0};
std::string name{"John"};
```

#### 作用域

```cpp
// Java - 块级作用域
{
    int x = 10;
}
// x在这里不可访问

// C++ - 相同的块级作用域
{
    int x = 10;
}
// x在这里不可访问
```

### 8. C++和Java的常量对比

#### Java常量

```java
// final关键字
final int MAX_SIZE = 100;
final String APP_NAME = "MyApp";

// 类常量
public class Constants {
    public static final double PI = 3.14159;
}
```

#### C++常量

```cpp
// const关键字
const int MAX_SIZE = 100;
const std::string APP_NAME = "MyApp";

// constexpr编译期常量(C++11)
constexpr int MAX_SIZE = 100;
constexpr double PI = 3.14159;

// 宏定义(不推荐)
#define MAX_SIZE 100

// 枚举类(C++11)
enum class Color { RED, GREEN, BLUE };
```

#### 常量对比

| 特性 | Java | C++ |
|------|------|-----|
| 关键字 | final | const/constexpr |
| 类常量 | static final | static constexpr |
| 编译时计算 | 支持 | constexpr支持 |
| 内联 | 可能 | const默认内联 |

### 9. C++与Java的赋值对比

#### 基本类型赋值

```cpp
// Java
int a = 10;
int b = a; // 值拷贝

// C++ - 相同
int a = 10;
int b = a; // 值拷贝
```

#### 对象赋值

```cpp
// Java - 引用拷贝
MyClass obj1 = new MyClass();
MyClass obj2 = obj1; // obj1和obj2指向同一对象

// C++ - 可以值拷贝或引用拷贝
MyClass obj1;
MyClass obj2 = obj1; // 调用拷贝构造函数，值拷贝
MyClass& obj3 = obj1; // 引用，obj3和obj1是同一对象
```

#### 赋值运算符重载

```cpp
// Java - 不支持运算符重载

// C++ - 可以重载赋值运算符
class MyClass {
public:
    MyClass& operator=(const MyClass& other) {
        if (this != &other) {
            // 拷贝逻辑
            this->data = other.data;
        }
        return *this;
    }
private:
    int data;
};
```

### 10. C++与Java的注释

#### 单行注释

```cpp
// Java
// 这是单行注释

// C++ - 相同
// 这是单行注释
```

#### 多行注释

```cpp
// Java
/* 这是多行注释
   可以跨越多行 */

// C++ - 相同
/* 这是多行注释
   可以跨越多行 */
```

#### 文档注释

```cpp
// Java - Javadoc风格
/**
 * 这是一个文档注释
 * @param name 参数说明
 * @return 返回值说明
 */

// C++ - Doxygen风格
/**
 * @brief 这是一个文档注释
 * @param name 参数说明
 * @return 返回值说明
 */
```

### 11. C++和Java的访问权限设置区别

#### 访问修饰符对比

| Java | C++ | 说明 |
|------|-----|------|
| public | public | 任何地方都可访问 |
| protected | protected | 类和派生类可访问 |
| default(包访问) | (无) | 友元和类可访问 |
| private | private | 仅类内部可访问 |

#### Java的访问控制

```java
public class MyClass {
    public int publicVar;
    protected int protectedVar;
    int defaultVar; // 包访问权限
    private int privateVar;
}
```

#### C++的访问控制

```cpp
class MyClass {
public:     // 公有部分
    int publicVar;

protected:  // 保护部分
    int protectedVar;

private:    // 私有部分
    int privateVar;

    // C++特有的友元
    friend class FriendClass;
};
```

#### C++特有的访问控制

```cpp
// 友元函数
class MyClass {
private:
    int secret;

    // 声明友元函数，可以访问私有成员
    friend void friendFunction(MyClass& obj);
};

void friendFunction(MyClass& obj) {
    obj.secret = 42; // 可以访问私有成员
}

// 友元类
class A {
private:
    int data;

    friend class B; // B类可以访问A的私有成员
};

class B {
public:
    void accessA(A& a) {
        a.data = 10; // 可以访问A的私有成员
    }
};
```

### 12. C++与Java程序文件的后缀名对比

#### 文件后缀名

| 语言 | 源文件 | 头文件 | 编译输出 | 可执行文件 |
|------|--------|--------|----------|------------|
| Java | .java | 无 | .class | .jar |
| C++ | .cpp/.cxx/.cc | .h/.hpp | .o/.obj | .exe/.out |

#### 编译和运行

```bash
# Java
javac Main.java        # 编译
java Main               # 运行

# C++ (g++)
g++ Main.cpp -o Main   # 编译链接
./Main                 # 运行 (Linux)
Main.exe               # 运行 (Windows)
```

### 13. C++与Java选择结构的对比

#### if-else语句

```cpp
// Java
if (condition) {
    // 代码
} else if (anotherCondition) {
    // 代码
} else {
    // 代码
}

// C++ - 相同
if (condition) {
    // 代码
} else if (anotherCondition) {
    // 代码
} else {
    // 代码
}
```

#### switch语句

```cpp
// Java
switch (value) {
    case 1:
        // 代码
        break;
    case 2:
        // 代码
        break;
    default:
        // 代码
}

// C++ - 相同
switch (value) {
    case 1:
        // 代码
        break;
    case 2:
        // 代码
        break;
    default:
        // 代码
}
```

#### C++特有的初始化if语句(C++17)

```cpp
// C++17 - if初始化语句
if (auto result = getData(); result.isValid()) {
    useResult(result);
} else {
    handleError(result);
}

// 等价于Java
var result = getData();
if (result.isValid()) {
    useResult(result);
} else {
    handleError(result);
}
```

### 14. C++与Java循环结构的对比

#### for循环

```cpp
// Java
for (int i = 0; i < 10; i++) {
    System.out.println(i);
}

// C++ - 相同
for (int i = 0; i < 10; i++) {
    std::cout << i << std::endl;
}
```

#### 增强for循环

```cpp
// Java - for-each
for (String item : list) {
    System.out.println(item);
}

// C++11 - 范围for循环
for (const auto& item : list) {
    std::cout << item << std::endl;
}
```

#### while循环

```cpp
// Java
while (condition) {
    // 代码
}

// C++ - 相同
while (condition) {
    // 代码
}
```

#### do-while循环

```cpp
// Java
do {
    // 代码
} while (condition);

// C++ - 相同
do {
    // 代码
} while (condition);
```

#### C++特有的循环控制

```cpp
// C++ - 基于范围的for循环(C++11)
std::vector<int> numbers = {1, 2, 3, 4, 5};

// 值拷贝
for (auto num : numbers) {
    std::cout << num << " ";
}

// 引用避免拷贝
for (const auto& num : numbers) {
    std::cout << num << " ";
}

// 可修改引用
for (auto& num : numbers) {
    num *= 2; // 修改原始数据
}

// C++20 - 结构化绑定
std::map<std::string, int> ages = {{"Alice", 25}, {"Bob", 30}};

for (const auto& [name, age] : ages) {
    std::cout << name << ": " << age << std::endl;
}
```

### 15. C++与Java的数组对比

#### 数组声明和初始化

```cpp
// Java - 数组是对象
int[] numbers = new int[5];
numbers[0] = 10;

int[] arr = {1, 2, 3, 4, 5};

// C++ - 数组是值类型
int numbers[5];
numbers[0] = 10;

int arr[] = {1, 2, 3, 4, 5};

// C++11 - std::array(推荐)
#include <array>
std::array<int, 5> numbers = {1, 2, 3, 4, 5};
```

#### 动态数组

```cpp
// Java - ArrayList
ArrayList<Integer> list = new ArrayList<>();
list.add(10);
list.add(20);

// C++ - std::vector
#include <vector>
std::vector<int> list;
list.push_back(10);
list.push_back(20);
```

#### 数组特性对比

| 特性 | Java数组 | C++数组 |
|------|----------|---------|
| 类型 | 对象 | 值类型 |
| 边界检查 | 运行时检查 | 不检查(可越界) |
| 长度 | .length属性 | sizeof(arr)/sizeof(type) |
| 多维数组 | 支持 | 支持 |
| 动态大小 | ArrayList | std::vector |

### 16. C++的指针和引用与Java的引用类型对比

#### Java的引用

```java
// Java中只有引用类型，没有显式指针
MyClass obj = new MyClass();
MyClass ref = obj; // ref和obj指向同一对象
```

#### C++的指针

```cpp
// C++指针 - 显式内存地址
int value = 42;
int* ptr = &value; // ptr存储value的地址

*ptr = 100; // 通过指针修改value

// 指针运算
int arr[] = {10, 20, 30};
int* ptr = arr;
ptr++; // 指向下一个元素
```

#### C++的引用

```cpp
// C++引用 - 已存在对象的别名
int value = 42;
int& ref = value; // ref是value的别名

ref = 100; // 修改了value

// 引用必须初始化，不能重新绑定
int another = 50;
ref = another; // 这是赋值，不是重新绑定

// 引用vs指针
void byPointer(int* ptr) {
    *ptr = 100;
}

void byReference(int& ref) {
    ref = 100;
}
```

#### 智能指针(C++11)

```cpp
#include <memory>

// unique_ptr - 独占所有权
std::unique_ptr<MyClass> ptr = std::make_unique<MyClass>();

// shared_ptr - 共享所有权
std::shared_ptr<MyClass> ptr1 = std::make_shared<MyClass>();
std::shared_ptr<MyClass> ptr2 = ptr1; // 共享所有权

// weak_ptr - 弱引用，不增加引用计数
std::weak_ptr<MyClass> weakPtr = ptr1;
```

### 17. C++中的内存管理与Java的垃圾回收对比

#### Java的内存管理

```java
// Java - 自动垃圾回收
public class MemoryExample {
    public void createObjects() {
        String str = new String("Hello");
        List<Integer> list = new ArrayList<>();
        // 对象使用完后，GC自动回收
    }
}
```

#### C++的内存管理

```cpp
// C++ - 手动内存管理
class MemoryExample {
public:
    void createObjects() {
        // 栈上分配 - 自动释放
        std::string str = "Hello";
        std::vector<int> list;

        // 堆上分配 - 手动管理
        int* ptr = new int(42);
        delete ptr; // 必须手动释放

        // 数组分配释放
        int* arr = new int[10];
        delete[] arr; // 必须使用delete[]
    }
};

// RAII原则 - 资源获取即初始化
class RAIIExample {
private:
    int* data;
public:
    RAIIExample() : data(new int(42)) {}

    ~RAIIExample() {
        delete data; // 析构函数自动释放资源
    }
};
```

#### 智能指针内存管理

```cpp
#include <memory>

void modernCpp() {
    // 使用智能指针，自动管理内存
    auto ptr = std::make_unique<int>(42);
    // 超出作用域自动释放，不需要手动delete
}
```

#### 内存管理对比

| 特性 | Java | C++ |
|------|------|-----|
| 内存分配 | new关键字 | new关键字/栈分配 |
| 内存释放 | GC自动回收 | 手动delete/智能指针 |
| 内存泄漏 | 较少发生 | 容易发生 |
| 性能开销 | GC暂停 | 无额外开销 |
| 确定性 | 非确定性释放 | 确定性释放 |

### 18. C++相关的数据容器和Java的集合框架对比

#### 容器对应关系

| Java | C++ | 说明 |
|------|-----|------|
| ArrayList | std::vector | 动态数组 |
| LinkedList | std::list | 双向链表 |
| HashSet | std::unordered_set | 无序集合 |
| TreeSet | std::set | 有序集合 |
| HashMap | std::unordered_map | 无序映射 |
| TreeMap | std::map | 有序映射 |
| PriorityQueue | std::priority_queue | 优先队列 |
| Stack | std::stack | 栈 |
| ArrayDeque | std::deque | 双端队列 |

#### 示例代码对比

```cpp
// Java - ArrayList
ArrayList<String> list = new ArrayList<>();
list.add("Hello");
list.add("World");

// C++ - std::vector
#include <vector>
std::vector<std::string> list;
list.push_back("Hello");
list.push_back("World");

// Java - HashMap
HashMap<String, Integer> map = new HashMap<>();
map.put("Alice", 25);
map.put("Bob", 30);

// C++ - std::unordered_map
#include <unordered_map>
std::unordered_map<std::string, int> map;
map["Alice"] = 25;
map["Bob"] = 30;
```

#### C++迭代器

```cpp
#include <vector>
#include <iostream>

std::vector<int> numbers = {1, 2, 3, 4, 5};

// 传统迭代器
for (auto it = numbers.begin(); it != numbers.end(); ++it) {
    std::cout << *it << " ";
}

// 范围for循环(C++11)
for (const auto& num : numbers) {
    std::cout << num << " ";
}

// 算法库使用
#include <algorithm>
std::sort(numbers.begin(), numbers.end());
```

### 19. C++中的函数和Java中的方法对比

#### 函数定义

```cpp
// Java - 方法必须在类中
public class MyClass {
    public int add(int a, int b) {
        return a + b;
    }
}

// C++ - 函数可以独立存在
int add(int a, int b) {
    return a + b;
}

// 或者作为类的成员函数
class MyClass {
public:
    int add(int a, int b) {
        return a + b;
    }
};
```

#### 函数参数

```cpp
// Java - 值传递和引用传递
public void modify(int num, StringBuilder sb) {
    num = 10; // 不影响原始值
    sb.append("text"); // 影响原始对象
}

// C++ - 值传递、指针传递、引用传递
void modify(int num, int* ptr, int& ref) {
    num = 10;    // 不影响原始值
    *ptr = 20;   // 影响原始值
    ref = 30;    // 影响原始值
}

// 使用示例
int value = 5;
int* ptr = &value;
int& ref = value;
modify(value, ptr, ref);
```

#### 默认参数

```cpp
// Java - 方法重载实现
public void print(String text) {
    print(text, "INFO");
}

public void print(String text, String level) {
    System.out.println(level + ": " + text);
}

// C++ - 默认参数
void print(const std::string& text, const std::string& level = "INFO") {
    std::cout << level << ": " << text << std::endl;
}

print("Hello");           // 使用默认参数
print("Hello", "ERROR");  // 指定参数
```

### 20. C++的命名空间和Java的包机制对比

#### Java包

```java
package com.example.myapp;

public class MyClass {
    // ...
}

// 使用
import com.example.myapp.MyClass;
// 或者
com.example.myapp.MyClass obj = new com.example.myapp.MyClass();
```

#### C++命名空间

```cpp
namespace com {
namespace example {
namespace myapp {

class MyClass {
    // ...
};

} // namespace myapp
} // namespace example
} // namespace com

// 使用
using com::example::myapp::MyClass;
MyClass obj;

// 或者直接使用
com::example::myapp::MyClass obj;

// C++17 - 嵌套命名空间简化
namespace com::example::myapp {
    class MyClass {
        // ...
    };
}
```

#### 命名空间别名

```cpp
// C++ - 命名空间别名
namespace app = com::example::myapp;

app::MyClass obj;
```

### 21. C++的标准输出库iostream和Java的输出打印库对比

#### Java输出

```java
// System.out
System.out.println("Hello, World!");
System.out.print("No newline");
System.out.printf("Name: %s, Age: %d\n", "John", 25);
```

#### C++输出

```cpp
#include <iostream>
#include <string>

// std::cout
std::cout << "Hello, World!" << std::endl;
std::cout << "No newline";

// std::cerr (错误输出)
std::cerr << "Error message" << std::endl;

// C++20 - std::format
#include <format>
std::string text = std::format("Name: {}, Age: {}", "John", 25);
std::cout << text << std::endl;
```

#### 格式化输出对比

```cpp
// Java - String.format()
String result = String.format("Name: %s, Age: %d", "John", 25);

// C++11 - iomanip
#include <iomanip>
std::cout << std::setw(10) << "Hello" << std::endl;

// C++20 - std::format
std::string result = std::format("Name: {}, Age: {}", "John", 25);
```

### 22. C++的面向对象相关知识

#### 类定义对比

```cpp
// Java
public class Person {
    private String name;
    private int age;

    public Person(String name, int age) {
        this.name = name;
        this.age = age;
    }

    public void sayHello() {
        System.out.println("Hello, I'm " + name);
    }
}

// C++
class Person {
private:
    std::string name;
    int age;

public:
    Person(const std::string& name, int age) : name(name), age(age) {}

    void sayHello() {
        std::cout << "Hello, I'm " << name << std::endl;
    }
};
```

#### 继承对比

```cpp
// Java
public class Animal {
    public void eat() {
        System.out.println("Animal is eating");
    }
}

public class Dog extends Animal {
    @Override
    public void eat() {
        System.out.println("Dog is eating");
    }
}

// C++
class Animal {
public:
    virtual void eat() {
        std::cout << "Animal is eating" << std::endl;
    }
};

class Dog : public Animal {
public:
    void eat() override {  // C++11的override关键字
        std::cout << "Dog is eating" << std::endl;
    }
};
```

#### 多态性

```cpp
// Java - 动态绑定
Animal animal = new Dog();
animal.eat(); // 调用Dog的eat方法

// C++ - 需要使用虚函数实现多态
Animal* animal = new Dog();
animal->eat(); // 调用Dog的eat方法

delete animal; // 多态删除
```

#### 抽象类

```cpp
// Java
public abstract class Shape {
    public abstract double getArea();
}

// C++
class Shape {
public:
    virtual double getArea() = 0; // 纯虚函数
    virtual ~Shape() = default;  // 虚析构函数
};
```

### 23. C++中多线程的实现和Java语言中线程的实现

#### Java多线程

```java
// 继承Thread类
public class MyThread extends Thread {
    @Override
    public void run() {
        System.out.println("Thread running");
    }
}

// 实现Runnable接口
public class MyRunnable implements Runnable {
    @Override
    public void run() {
        System.out.println("Runnable running");
    }
}

// 使用
Thread thread = new Thread(new MyRunnable());
thread.start();
```

#### C++多线程(C++11)

```cpp
#include <thread>
#include <iostream>

void threadFunction() {
    std::cout << "Thread running" << std::endl;
}

int main() {
    // 创建线程
    std::thread t(threadFunction);

    // 等待线程完成
    t.join();

    return 0;
}

// 使用lambda表达式
auto t = std::thread([]() {
    std::cout << "Lambda thread" << std::endl;
});
```

#### 线程同步对比

```cpp
// Java - synchronized
public synchronized void increment() {
    count++;
}

// C++ - std::mutex
#include <mutex>
std::mutex mtx;

void increment() {
    std::lock_guard<std::mutex> lock(mtx);
    count++;
}
```

### 24. C++中的模板与Java中的泛型对比

#### Java泛型

```java
// 泛型类
public class Container<T> {
    private T value;

    public Container(T value) {
        this.value = value;
    }

    public T getValue() {
        return value;
    }
}

// 使用
Container<String> stringContainer = new Container<>("Hello");
Container<Integer> intContainer = new Container<>(42);
```

#### C++模板

```cpp
// 模板类
template<typename T>
class Container {
private:
    T value;

public:
    Container(const T& value) : value(value) {}

    T getValue() const {
        return value;
    }
};

// 使用
Container<std::string> stringContainer("Hello");
Container<int> intContainer(42);

// 模板特化
template<>
class Container<bool> {
private:
    bool value;
public:
    // 特化实现
};
```

#### 模板元编程

```cpp
// 编译期计算
template<int N>
struct Factorial {
    static constexpr int value = N * Factorial<N - 1>::value;
};

template<>
struct Factorial<0> {
    static constexpr int value = 1;
};

// 编译期结果: Factorial<5>::value = 120
constexpr int result = Factorial<5>::value;
```

### 25. 变量作用域和生命周期

#### 局部变量

```cpp
// Java - 局部变量作用域
public void method() {
    int x = 10; // 方法作用域
    {
        int y = 20; // 块作用域
    }
    // y在这里不可访问
}

// C++ - 类似作用域规则
void function() {
    int x = 10; // 函数作用域
    {
        int y = 20; // 块作用域
    }
    // y在这里不可访问
}
```

#### 静态变量

```cpp
// Java - 静态变量
public class Counter {
    private static int count = 0; // 类级别，所有实例共享
}

// C++ - 静态变量
class Counter {
private:
    static int count; // 声明
};

int Counter::count = 0; // 定义
```

#### 全局变量

```cpp
// Java - 没有真正的全局变量，使用public static final

// C++ - 全局变量
int globalVar = 100; // 全局作用域

static int fileVar = 200; // 文件作用域
```

### 26. C++和Java字符串操作的区别

#### 字符串创建

```cpp
// Java
String str1 = "Hello";
String str2 = new String("World");

// C++
std::string str1 = "Hello";
std::string str2 = std::string("World");

// C风格字符串
const char* cstr = "C-style string";
```

#### 字符串操作

```cpp
// Java
String result = str1 + " " + str2;  // 字符串连接
int length = str1.length();          // 字符串长度
boolean equals = str1.equals(str2); // 字符串比较

// C++
std::string result = str1 + " " + str2;  // 字符串连接
size_t length = str1.length();            // 字符串长度
bool equals = (str1 == str2);            // 字符串比较

// C风格字符串操作
#include <cstring>
char buffer[100];
strcpy(buffer, "Hello");     // 复制
strcat(buffer, " World");   // 连接
int len = strlen(buffer);    // 长度
```

#### 字符串查找

```cpp
// Java
int index = str.indexOf("World");
boolean contains = str.contains("Hello");

// C++
size_t index = str.find("World");
bool contains = (str.find("Hello") != std::string::npos);
```

### 27. C++和Java的IO操作的区别

#### 文件读写

```cpp
// Java - FileInputStream/FileOutputStream
try (FileInputStream fis = new FileInputStream("input.txt");
     FileOutputStream fos = new FileOutputStream("output.txt")) {
    int data;
    while ((data = fis.read()) != -1) {
        fos.write(data);
    }
} catch (IOException e) {
    e.printStackTrace();
}

// C++ - fstream
#include <fstream>
#include <iostream>

int main() {
    std::ifstream inputFile("input.txt");
    std::ofstream outputFile("output.txt");

    if (!inputFile.is_open() || !outputFile.is_open()) {
        std::cerr << "无法打开文件" << std::endl;
        return 1;
    }

    char data;
    while (inputFile.get(data)) {
        outputFile.put(data);
    }

    inputFile.close();
    outputFile.close();

    return 0;
}
```

#### 文本文件读写

```cpp
// Java - BufferedReader/BufferedWriter
try (BufferedReader reader = new BufferedReader(new FileReader("input.txt"));
     BufferedWriter writer = new BufferedWriter(new FileWriter("output.txt"))) {
    String line;
    while ((line = reader.readLine()) != null) {
        writer.write(line);
        writer.newLine();
    }
}

// C++ - getline
#include <fstream>
#include <sstream>

std::ifstream inputFile("input.txt");
std::ofstream outputFile("output.txt");

std::string line;
while (std::getline(inputFile, line)) {
    outputFile << line << std::endl;
}
```

### 28. C++中的Lambda表达式和函数式编程与Java对比

#### Lambda表达式对比

```cpp
// Java - Lambda表达式
List<Integer> numbers = Arrays.asList(1, 2, 3, 4, 5);

// 遍历
numbers.forEach(n -> System.out.println(n));

// 过滤
List<Integer> evenNumbers = numbers.stream()
    .filter(n -> n % 2 == 0)
    .collect(Collectors.toList());

// C++ - Lambda表达式(C++11)
#include <algorithm>
#include <vector>
#include <iostream>

std::vector<int> numbers = {1, 2, 3, 4, 5};

// 遍历
std::for_each(numbers.begin(), numbers.end(),
    [](int n) { std::cout << n << " "; });

// 过滤(C++20 ranges)
#include <ranges>
auto evenNumbers = numbers | std::views::filter([](int n) {
    return n % 2 == 0;
});
```

#### Lambda捕获

```cpp
// Java - 捕获final或effectively final变量
int factor = 2;
numbers.forEach(n -> System.out.println(n * factor));

// C++ - 显式捕获列表
int factor = 2;
std::for_each(numbers.begin(), numbers.end(),
    [factor](int n) {       // 值捕获
        return n * factor;
    });

int sum = 0;
std::for_each(numbers.begin(), numbers.end(),
    [&sum](int n) {         // 引用捕获
        sum += n;
    });

// 混合捕获
int x = 1, y = 2;
auto lambda = [=, &y]() {  // x值捕获，y引用捕获
    return x + y;
};
```

### 29. C++中的map和Java中的HashMap

#### 基本使用

```cpp
// Java - HashMap
import java.util.HashMap;

HashMap<String, Integer> map = new HashMap<>();
map.put("Alice", 25);
map.put("Bob", 30);

int age = map.get("Alice");
boolean exists = map.containsKey("Charlie");

// C++ - std::unordered_map
#include <unordered_map>

std::unordered_map<std::string, int> map;
map["Alice"] = 25;
map["Bob"] = 30;

int age = map["Alice"];
bool exists = (map.find("Charlie") != map.end());

// C++ - std::map (有序映射)
#include <map>
std::map<std::string, int> orderedMap;
orderedMap["Alice"] = 25;
orderedMap["Bob"] = 30;

// 自动按键排序
```

#### 遍历

```cpp
// Java
for (Map.Entry<String, Integer> entry : map.entrySet()) {
    System.out.println(entry.getKey() + ": " + entry.getValue());
}

// C++11
for (const auto& pair : map) {
    std::cout << pair.first << ": " << pair.second << std::endl;
}

// C++17 - 结构化绑定
for (const auto& [key, value] : map) {
    std::cout << key << ": " << value << std::endl;
}
```

### 30. C++中的时间和日期处理与Java的Time API对比

#### 时间点

```cpp
// Java - LocalDateTime
import java.time.LocalDateTime;

LocalDateTime now = LocalDateTime.now();
int hour = now.getHour();
int minute = now.getMinute();

// C++ - std::chrono (C++11)
#include <chrono>
#include <iostream>

auto now = std::chrono::system_clock::now();
auto time = std::chrono::system_clock::to_time_t(now);
std::tm localTime = *std::localtime(&time);

int hour = localTime.tm_hour;
int minute = localTime.tm_min;
```

#### 时间间隔

```cpp
// Java - Duration
import java.time.Duration;

Duration duration = Duration.ofHours(2);
long seconds = duration.getSeconds();

// C++ - std::chrono::duration
#include <chrono>

std::chrono::duration<int, std::ratio<3600>> duration(2); // 2小时
auto seconds = std::chrono::duration_cast<std::chrono::seconds>(duration);
```

#### 时间测量

```cpp
// Java
long startTime = System.nanoTime();
// 执行代码
long endTime = System.nanoTime();
long duration = endTime - startTime;

// C++
#include <chrono>

auto startTime = std::chrono::high_resolution_clock::now();
// 执行代码
auto endTime = std::chrono::high_resolution_clock::now();
auto duration = std::chrono::duration_cast<std::chrono::microseconds>(endTime - startTime);
```

### 31. C++和Java关于网络编程的对比

#### TCP客户端

```cpp
// Java - Socket
import java.io.*;
import java.net.*;

Socket socket = new Socket("localhost", 8080);
InputStream input = socket.getInputStream();
OutputStream output = socket.getOutputStream();

// C++ - Boost.Asio
#include <boost/asio.hpp>

boost::asio::io_context io_context;
boost::asio::ip::tcp::socket socket(io_context);
boost::asio::ip::tcp::endpoint endpoint(
    boost::asio::ip::make_address("127.0.0.1"), 8080);

socket.connect(endpoint);
```

#### HTTP请求

```cpp
// Java - HttpURLConnection
URL url = new URL("https://example.com");
HttpURLConnection connection = (HttpURLConnection) url.openConnection();
connection.setRequestMethod("GET");

// C++ - cpr库 (推荐)
#include <cpr/cpr.h>

auto response = cpr::Get(cpr::Url{"https://example.com"});
std::cout << response.text << std::endl;
```

### 32. C++如何连接数据库

#### Java JDBC

```java
import java.sql.*;

public class DatabaseExample {
    public static void main(String[] args) {
        String url = "jdbc:mysql://localhost:3306/mydb";
        String user = "username";
        String password = "password";

        try (Connection conn = DriverManager.getConnection(url, user, password)) {
            Statement stmt = conn.createStatement();
            ResultSet rs = stmt.executeQuery("SELECT * FROM users");

            while (rs.next()) {
                String name = rs.getString("name");
                System.out.println(name);
            }
        } catch (SQLException e) {
            e.printStackTrace();
        }
    }
}
```

#### C++数据库连接

```cpp
// MySQL连接器
#include <mysql_driver.h>
#include <mysql_connection.h>

int main() {
    sql::mysql::MySQL_Driver *driver;
    sql::Connection *con;

    driver = sql::mysql::get_mysql_driver_instance();
    con = driver->connect("tcp://127.0.0.1:3306", "username", "password");

    con->setSchema("mydb");

    sql::Statement *stmt;
    sql::ResultSet *res;

    stmt = con->createStatement();
    res = stmt->executeQuery("SELECT * FROM users");

    while (res->next()) {
        std::cout << res->getString("name") << std::endl;
    }

    delete res;
    delete stmt;
    delete con;

    return 0;
}
```

### 33. C++中的依赖管理工具对比

#### Java依赖管理

```xml
<!-- Maven - pom.xml -->
<dependencies>
    <dependency>
        <groupId>org.springframework</groupId>
        <artifactId>spring-core</artifactId>
        <version>5.3.8</version>
    </dependency>
</dependencies>
```

#### C++依赖管理

```cmake
# CMake - CMakeLists.txt
find_package(Boost REQUIRED)
find_package(OpenSSL REQUIRED)

add_executable(myapp main.cpp)
target_link_libraries(myapp
    PRIVATE
    Boost::system
    OpenSSL::SSL
)
```

#### 现代C++包管理器

```bash
# Conan - C++包管理器
conan install boost/1.76.0@

# vcpkg - 微软的包管理器
vcpkg install boost:x64-linux

# CPM.cmake - CMake的依赖管理
include(cpm/CPM.cmake)
CPMAddPackage("gh.com/boostorg/boost#1.76.0")
```

### 34. C++的并发编程与Java的区别

#### 线程创建

```cpp
// Java
Thread thread = new Thread(() -> {
    System.out.println("Thread running");
});
thread.start();

// C++
std::thread thread([]() {
    std::cout << "Thread running" << std::endl;
});
thread.join();
```

#### 异步操作

```cpp
// Java - CompletableFuture
CompletableFuture.supplyAsync(() -> "Hello")
    .thenApplyAsync(String::toUpperCase)
    .thenAcceptAsync(System.out::println);

// C++ - std::async
#include <future>

auto future = std::async(std::launch::async, []() {
    return std::string("Hello");
});

auto result = future.get(); // 等待结果
std::transform(result.begin(), result.end(), result.begin(), ::toupper);
std::cout << result << std::endl;
```

#### 线程池

```cpp
// Java - ExecutorService
ExecutorService executor = Executors.newFixedThreadPool(4);
executor.submit(() -> {
    System.out.println("Task running");
});

// C++ - 需要自己实现或使用第三方库
// 标准库没有内置线程池，可以使用Boost.Asio或第三方实现
```

### 35. C++的性能优化和Java的性能优化

#### 编译优化

```cpp
// C++ - 编译器优化选项
// g++ -O2 -O3 -march=native

// Java - JVM优化
// -XX:+UseG1GC -XX:+UseStringDeduplication
```

#### 内存优化

```cpp
// C++ - 对象池、移动语义
std::vector<std::string> strings;

// 避免拷贝，使用移动语义
strings.push_back(std::move(tempString));

// 对象池模式
class ObjectPool {
private:
    std::vector<std::unique_ptr<MyObject>> pool;
public:
    MyObject* acquire() {
        if (pool.empty()) {
            return new MyObject();
        } else {
            auto obj = pool.back().release();
            pool.pop_back();
            return obj;
        }
    }

    void release(MyObject* obj) {
        pool.emplace_back(obj);
    }
};
```

#### 性能分析工具

```bash
# C++性能分析
# perf (Linux)
perf record ./myapp
perf report

# Valgrind内存分析
valgrind --tool=memcheck ./myapp

# Java性能分析
# JProfiler、VisualVM
jmap -heap <pid>
```

### 36. C++的测试框架与Java的单元测试

#### Java单元测试

```java
// JUnit测试
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class CalculatorTest {
    @Test
    public void testAdd() {
        Calculator calc = new Calculator();
        assertEquals(5, calc.add(2, 3));
    }

    @Test
    public void testException() {
        assertThrows(IllegalArgumentException.class, () -> {
            Calculator.divide(1, 0);
        });
    }
}
```

#### C++单元测试

```cpp
// Google Test框架
#include <gtest/gtest.h>

class CalculatorTest : public ::testing::Test {
protected:
    Calculator calc;
};

TEST_F(CalculatorTest, TestAdd) {
    EXPECT_EQ(calc.add(2, 3), 5);
}

TEST(CalculatorTest, TestException) {
    EXPECT_THROW(Calculator::divide(1, 0), std::invalid_argument);
}

int main(int argc, char** argv) {
    ::testing::InitGoogleTest(&argc, argv);
    return RUN_ALL_TESTS();
}
```

### 37. C++的类型推导与Java的var关键字

#### Java var

```java
// Java 10+ var关键字
var number = 42;           // 推导为int
var text = "Hello";        // 推导为String
var list = new ArrayList<String>();

// 限制：只能在局部变量中使用
public var field = 10;    // 编译错误
```

#### C++ auto

```cpp
// C++11 auto关键字
auto number = 42;              // 推导为int
auto text = std::string("Hello"); // 推导为std::string
auto list = std::vector<int>{};

// 更灵活
std::map<std::string, int> map;
for (const auto& [key, value] : map) { // C++17结构化绑定
    std::cout << key << ": " << value << std::endl;
}

// 函数返回类型推导(C++14)
auto add(int a, int b) {
    return a + b;  // 推导为int
}

// decltype类型推导
decltype(42) y = 10; // y的类型与42相同，即int
```

### 38. C++的异常处理与Java的异常处理对比

#### 异常处理结构

```cpp
// Java异常处理
try {
    // 可能抛出异常的代码
    int result = 10 / 0;
} catch (ArithmeticException e) {
    System.out.println("数学异常: " + e.getMessage());
} catch (Exception e) {
    System.out.println("其他异常: " + e.getMessage());
} finally {
    // 总是执行的代码
    System.out.println("清理资源");
}

// C++异常处理
try {
    // 可能抛出异常的代码
    int result = 10 / 0;
} catch (const std::runtime_error& e) {
    std::cout << "运行时异常: " << e.what() << std::endl;
} catch (const std::exception& e) {
    std::cout << "其他异常: " << e.what() << std::endl;
}

// C++中没有finally，使用RAII替代
```

#### 自定义异常

```cpp
// Java自定义异常
public class MyException extends Exception {
    public MyException(String message) {
        super(message);
    }
}

// C++自定义异常
#include <stdexcept>

class MyException : public std::runtime_error {
public:
    explicit MyException(const std::string& message)
        : std::runtime_error(message) {}
};

// 使用
try {
    throw MyException("自定义异常");
} catch (const MyException& e) {
    std::cout << e.what() << std::endl;
}
```

#### 异常规范

```cpp
// Java异常声明
public void myMethod() throws IOException, SQLException {
    // 可能抛出这些异常的方法
}

// C++异常规范(C++17前已废弃，C++20移除)
// 旧方式: 不推荐
void myMethod() throw(std::runtime_error) {
    // 可能抛出运行时异常
}

// C++17 - noexcept
void myMethod() noexcept {
    // 不抛出异常的函数
}

void anotherMethod() noexcept(false) {
    // 可能抛出异常
}
```

### 39. C++的函数重载与Java的方法重载

#### 函数重载

```cpp
// Java方法重载
public class Calculator {
    public int add(int a, int b) {
        return a + b;
    }

    public double add(double a, double b) {
        return a + b;
    }

    public int add(int a, int b, int c) {
        return a + b + c;
    }
}

// C++函数重载
class Calculator {
public:
    int add(int a, int b) {
        return a + b;
    }

    double add(double a, double b) {
        return a + b;
    }

    int add(int a, int b, int c) {
        return a + b + c;
    }
};
```

#### 参数匹配

```cpp
// Java - 严格类型匹配
Calculator calc = calc.add(1, 2);      // 调用add(int, int)
calc.add(1.0, 2.0);                    // 调用add(double, double)

// C++ - 包含类型转换
Calculator calc;
calc.add(1, 2);      // 调用add(int, int)
calc.add(1.0, 2.0);  // 调用add(double, double)
calc.add(1, 2.0);    // 调用add(double, double) - int转换为double
```

### 40. C++的运算符重载与Java的对比

#### Java - 不支持运算符重载

```java
// Java不支持运算符重载，必须使用方法调用
Complex a = new Complex(1, 2);
Complex b = new Complex(3, 4);
Complex result = a.add(b);  // 方法调用
```

#### C++ - 支持运算符重载

```cpp
#include <iostream>

class Complex {
private:
    double real, imag;

public:
    Complex(double r, double i) : real(r), imag(i) {}

    // 运算符重载
    Complex operator+(const Complex& other) const {
        return Complex(real + other.real, imag + other.imag);
    }

    Complex operator*(const Complex& other) const {
        return Complex(real * other.real - imag * other.imag,
                       real * other.imag + imag * other.real);
    }

    friend std::ostream& operator<<(std::ostream& os, const Complex& c) {
        os << c.real << " + " << c.imag << "i";
        return os;
    }
};

// 使用
Complex a(1, 2);
Complex b(3, 4);
Complex result = a + b;  // 使用重载的+运算符
std::cout << result << std::endl;
```

### 41. C++的友元与Java的对比

#### Java - 无友元概念

```java
// Java没有友元概念，只有public、protected、private
class MyClass {
    private int secret;

    public int getSecret() {
        return secret;  // 通过public方法访问
    }
}
```

#### C++ - 友元函数和友元类

```cpp
class MyClass {
private:
    int secret;

    // 友元函数声明
    friend void friendFunction(MyClass& obj);

    // 友元类声明
    friend class FriendClass;
};

// 友元函数定义
void friendFunction(MyClass& obj) {
    obj.secret = 42;  // 可以访问私有成员
}

// 友元类
class FriendClass {
public:
    void accessMyClass(MyClass& obj) {
        obj.secret = 100;  // 可以访问私有成员
    }
};
```

### 42. C++的虚函数与多态与Java的对比

#### Java - 动态绑定

```java
// Java的所有非static、非final方法都是虚方法
class Animal {
    public void makeSound() {
        System.out.println("Animal sound");
    }
}

class Dog extends Animal {
    @Override
    public void makeSound() {
        System.out.println("Bark");
    }
}

// 使用
Animal animal = new Dog();
animal.makeSound();  // 输出 "Bark"
```

#### C++ - 需要显式声明虚函数

```cpp
class Animal {
public:
    // 虚函数 - 实现多态
    virtual void makeSound() {
        std::cout << "Animal sound" << std::endl;
    }

    // 虚析构函数 - 确保正确删除派生类对象
    virtual ~Animal() = default;
};

class Dog : public Animal {
public:
    void makeSound() override {  // override关键字(C++11)
        std::cout << "Bark" << std::endl;
    }
};

// 使用
Animal* animal = new Dog();
animal->makeSound();  // 输出 "Bark"
delete animal;         // 调用正确的析构函数
```

#### 纯虚函数和抽象类

```cpp
// Java抽象类
public abstract class Shape {
    public abstract double getArea();
}

// C++抽象类
class Shape {
public:
    virtual double getArea() = 0;  // 纯虚函数
    virtual ~Shape() = default;
};

class Circle : public Shape {
private:
    double radius;

public:
    Circle(double r) : radius(r) {}

    double getArea() override {
        return 3.14159 * radius * radius;
    }
};
```

### 43. C++的RAII与Java的try-with-resources对比

#### Java - try-with-resources

```java
// Java的try-with-resources自动管理资源
try (FileInputStream fis = new FileInputStream("input.txt");
     BufferedReader br = new BufferedReader(new FileReader("input.txt"))) {

    String line;
    while ((line = br.readLine()) != null) {
        System.out.println(line);
    }
} catch (IOException e) {
    e.printStackTrace();
}
// 资源自动关闭
```

#### C++ - RAII原则

```cpp
#include <fstream>
#include <iostream>

// RAII - 资源获取即初始化
void readFile() {
    // 资源在构造时获取，在析构时释放
    std::ifstream inputFile("input.txt");
    std::string line;

    while (std::getline(inputFile, line)) {
        std::cout << line << std::endl;
    }
    // 文件自动关闭，无需显式调用close()
}

// 自定义RAII类
class FileHandler {
private:
    FILE* file;

public:
    FileHandler(const char* filename, const char* mode) {
        file = fopen(filename, mode);
        if (!file) {
            throw std::runtime_error("无法打开文件");
        }
    }

    ~FileHandler() {
        if (file) {
            fclose(file);  // 自动关闭文件
        }
    }

    // 禁止拷贝
    FileHandler(const FileHandler&) = delete;
    FileHandler& operator=(const FileHandler&) = delete;
};

// 使用
void processFile() {
    FileHandler file("input.txt", "r");
    // 使用文件
    // 文件自动关闭
}
```

### 44. C++的移动语义与Java的对比

#### Java - 只有引用传递

```java
// Java中对象传递都是引用传递，没有移动语义
public class Container {
    private List<String> data;

    public Container(List<String> data) {
        this.data = data;  // 引用拷贝
    }
}
```

#### C++ - 移动语义(C++11)

```cpp
#include <vector>
#include <iostream>

class Container {
private:
    std::vector<int> data;

public:
    // 拷贝构造函数
    Container(const std::vector<int>& d) : data(d) {
        std::cout << "拷贝构造" << std::endl;
    }

    // 移动构造函数
    Container(std::vector<int>&& d) : data(std::move(d)) {
        std::cout << "移动构造" << std::endl;
    }
};

// 使用
int main() {
    std::vector<int> numbers = {1, 2, 3, 4, 5};

    // 拷贝
    Container c1(numbers);  // 调用拷贝构造函数

    // 移动
    Container c2(std::move(numbers));  // 调用移动构造函数

    // numbers现在为空，因为被移动了
    std::cout << "numbers size: " << numbers.size() << std::endl;

    return 0;
}
```

#### 移动赋值运算符

```cpp
class MyClass {
private:
    int* data;
    size_t size;

public:
    // 移动赋值运算符
    MyClass& operator=(MyClass&& other) noexcept {
        if (this != &other) {
            delete[] data;               // 释放当前资源
            data = other.data;           // 移动资源
            size = other.size;
            other.data = nullptr;       // 重置源对象
            other.size = 0;
        }
        return *this;
    }
};
```

### 45. C++的智能指针与Java的对比

#### Java - 自动垃圾回收

```java
// Java的对象由垃圾回收器管理
public class Example {
    public void createObjects() {
        String str = new String("Hello");
        List<Integer> numbers = new ArrayList<>();
        // GC自动管理内存，开发者无需手动释放
    }
}
```

#### C++ - 智能指针

```cpp
#include <memory>
#include <iostream>

class MyClass {
public:
    MyClass() { std::cout << "构造" << std::endl; }
    ~MyClass() { std::cout << "析构" << std::endl; }
    void doSomething() { std::cout << "做某事" << std::endl; }
};

void useUniquePtr() {
    // unique_ptr - 独占所有权，不可拷贝
    std::unique_ptr<MyClass> ptr = std::make_unique<MyClass>();
    ptr->doSomething();

    // 所有权转移
    std::unique_ptr<MyClass> ptr2 = std::move(ptr);
    // ptr现在为空
    // ptr2->doSomething();

    // 超出作用域自动删除
}

void useSharedPtr() {
    // shared_ptr - 共享所有权，可以拷贝
    std::shared_ptr<MyClass> ptr1 = std::make_shared<MyClass>();
    std::shared_ptr<MyClass> ptr2 = ptr1;  // 共享所有权

    std::cout << "引用计数: " << ptr1.use_count() << std::endl;  // 输出2

    ptr1->doSomething();
    ptr2->doSomething();

    // 当最后一个shared_ptr被销毁时，对象被删除
}

void useWeakPtr() {
    // weak_ptr - 弱引用，不影响引用计数
    std::shared_ptr<MyClass> shared = std::make_shared<MyClass>();
    std::weak_ptr<MyClass> weak = shared;

    std::cout << "弱引用计数: " << weak.use_count() << std::endl;  // 输出1

    if (auto locked = weak.lock()) {
        locked->doSomething();
    }
}
```

### 46. C++的预处理指令与Java的注解对比

#### Java - 注解

```java
// Java注解 - 元数据
@Override
@SuppressWarnings("unchecked")
@Deprecated
public void myMethod() {
    // 方法实现
}

// 自定义注解
public @interface MyAnnotation {
    String value() default "";
    int count() default 0;
}

@MyAnnotation(value = "example", count = 5)
public class MyClass {
    // 类实现
}
```

#### C++ - 预处理指令

```cpp
// C++预处理指令
#include <iostream>     // 文件包含
#define PI 3.14159      // 宏定义
#define MAX(a, b) ((a) > (b) ? (a) : (b))  // 宏函数

#ifdef DEBUG            // 条件编译
    std::cout << "Debug mode" << std::endl;
#endif

// 预定义宏
std::cout << "文件: " << __FILE__ << std::endl;
std::cout << "行号: " << __LINE__ << std::endl;
std::cout << "日期: " << __DATE__ << std::endl;
std::cout << "时间: " << __TIME__ << std::endl;

// C++20 - 属性(类似注解)
class MyClass {
    [[nodiscard]] int* getData();  // 返回值不能被忽略

    [[deprecated("使用newMethod代替")]]
    void oldMethod();  // 标记为废弃
};

// 使用
MyClass obj;
obj.getData();  // 警告：返回值被忽略
obj.oldMethod(); // 警告：方法已废弃
```

---

## 四、C++最佳实践和常见陷阱

### 1. 现代C++最佳实践

#### 使用C++11及更高版本

```cpp
// 推荐使用现代C++特性
auto result = std::make_unique<MyClass>();  // 而不是 new MyClass()
std::vector<int> numbers = {1, 2, 3, 4, 5}; // 而不是传统数组

// 使用智能指针管理内存
std::shared_ptr<MyClass> shared = std::make_shared<MyClass>();

// 使用RAII管理资源
std::lock_guard<std::mutex> lock(mutex);  // 自动释放锁
```

#### 避免内存泄漏

```cpp
// 错误示例 - 内存泄漏
void badExample() {
    int* ptr = new int(42);
    // 忘记delete - 内存泄漏
}

// 正确示例 - 使用智能指针
void goodExample() {
    auto ptr = std::make_unique<int>(42);
    // 自动释放，无需手动delete
}
```

#### 使用标准库

```cpp
// 优先使用标准库而不是自己实现
std::vector<int> data;           // 而不是动态数组
std::map<std::string, int> map;  // 而不是自己实现的映射
std::sort(data.begin(), data.end()); // 而不是自己实现排序
```

### 2. 常见陷阱和解决方案

#### 数组越界

```cpp
// 错误示例 - 数组越界
int arr[5];
arr[10] = 42;  // 未定义行为

// 解决方案 - 使用std::vector和at()
std::vector<int> arr(5);
arr.at(10) = 42;  // 抛出std::out_of_range异常
```

#### 悬空指针

```cpp
// 错误示例 - 悬空指针
int* createPtr() {
    int value = 42;
    return &value;  // 返回局部变量地址
}

// 解决方案 - 使用智能指针或返回值
std::unique_ptr<int> createPtr() {
    return std::make_unique<int>(42);
}
```

#### 拷贝性能问题

```cpp
// 错误示例 - 不必要的拷贝
std::vector<int> process(std::vector<int> data) {
    // 参数传递导致拷贝
    return data;  // 返回又导致拷贝
}

// 解决方案 - 使用移动语义和引用
std::vector<int> process(std::vector<int>& data) {
    // 引用传递，避免拷贝
    return std::move(data);  // 移动返回
}

// 或者使用const引用
size_t getSize(const std::vector<int>& data) {
    return data.size();
}
```

### 3. 性能优化建议

#### 避免不必要的内存分配

```cpp
// 预分配空间
std::vector<int> numbers;
numbers.reserve(1000);  // 预分配空间，避免重新分配

// 使用emplace_back代替push_back
std::vector<std::string> strings;
strings.emplace_back("Hello");  // 原地构造，避免临时对象
```

#### 使用移动语义

```cpp
// 大对象传递时使用移动语义
std::vector<int> createLargeVector() {
    std::vector<int> result(1000000);
    return result;  // C++11自动移动
}

// 显式移动
std::vector<int> data = createLargeVector();
std::vector<int> newData = std::move(data);  // 移动而非拷贝
```

#### 编译期优化

```cpp
// 使用constexpr编译期计算
constexpr int factorial(int n) {
    return (n <= 1) ? 1 : (n * factorial(n - 1));
}

constexpr int result = factorial(5);  // 编译期计算，运行时无开销

// 使用模板元编程
template<int N>
struct Factorial {
    static constexpr int value = N * Factorial<N - 1>::value;
};

template<>
struct Factorial<0> {
    static constexpr int value = 1;
};

constexpr int result2 = Factorial<5>::value;  // 编译期结果
```

### 4. 调试技巧

#### 使用静态分析工具

```bash
# clang-tidy - 静态代码分析
clang-tidy main.cpp -- -std=c++17

# cppcheck - 静态分析
cppcheck --enable=all main.cpp

# Valgrind - 内存泄漏检测
valgrind --leak-check=full ./myapp
```

#### 使用调试器

```cpp
// GDB调试
// 编译时添加调试信息
// g++ -g main.cpp -o myapp

// 常用GDB命令
// break main    - 设置断点
// run           - 运行程序
// next          - 单步执行
// step          - 进入函数
// print variable - 查看变量值
// continue      - 继续执行
```

---

## 总结

C++是一门功能强大且灵活的编程语言，相比Java具有：

### 优势
- **极致性能**：直接编译为机器码，无虚拟机开销
- **底层控制**：精确的内存管理和硬件控制
- **多范式编程**：支持面向对象、泛型、函数式编程
- **零开销抽象**：现代C++的抽象不带来运行时成本
- **丰富的标准库**：STL提供强大的数据结构和算法

### 挑战
- **学习曲线陡峭**：概念复杂，需要深入理解
- **内存管理**：需要手动管理或使用智能指针
- **编译复杂**：构建系统和依赖管理较为复杂
- **安全性**：容易犯内存相关的错误

### 学习建议
1. **从现代C++开始**：建议从C++11或更高版本开始学习
2. **理解内存管理**：掌握智能指针和RAII原则
3. **使用标准库**：优先使用STL而不是自己实现
4. **实践项目**：通过实际项目加深理解
5. **关注性能**：理解移动语义和编译期优化

掌握C++需要时间和实践，但一旦掌握，你将拥有一门强大而灵活的编程工具！