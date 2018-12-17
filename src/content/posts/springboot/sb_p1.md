+++
title = "Spring Boot 源码分析(1)"
description = ""
tags = [
    "spring boot"
]
date = "2018-12-17 13:19:48.287 +0800"
categories = [
    "spring"
]
+++


#### 启动代码
```
@SpringBootApplication
public class Run {

	public static void main(String[] args) {

		SpringApplication app = new SpringApplication(Run.class);

		app.run(args);


	}

}

```
