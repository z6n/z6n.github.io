+++
title = "Spring Boot 源码分析(1)"
description = ""
tags = [
    "spring boot",
    "sources"
]
date = "2018-12-17 13:19:48.287 +0800"
categories = [
    "spring"
]
+++

### 源码版本

* spring boot 2.1.0.RELEASE  

<br/>

### 入口代码
```
@SpringBootApplication
public class Run {

	public static void main(String[] args) {

		SpringApplication app = new SpringApplication(Run.class); // 1

		app.run(args);  // 2


	}

}

```

#### 构造方法中的加载过程  

-----------


 在new SpringApplication(Run.class)中实际调用的是`SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources)`构造方法，在构造方法中主要执行了一些必要的查找初始化工作。
<br/>
<br/>
<br/>

```
public SpringApplication(ResourceLoader resourceLoader, Class<?>... primarySources) {
		this.resourceLoader = resourceLoader;
		Assert.notNull(primarySources, "PrimarySources must not be null");
		this.primarySources = new LinkedHashSet<>(Arrays.asList(primarySources));  
		this.webApplicationType = WebApplicationType.deduceFromClasspath();  // 1-1
		setInitializers((Collection) getSpringFactoriesInstances(
				ApplicationContextInitializer.class));                       // 1-2
		setListeners((Collection) getSpringFactoriesInstances(ApplicationListener.class)); // 1-3
		this.mainApplicationClass = deduceMainApplicationClass();
	}
```

<br/>

  1-1. 主要通过classpath中的类判断应用什么类型(WebApplicationType NONE, SERVLET, REACTIVE)  
  1-2. 扫描classpath:META-INF/spring.factories 文件中定义的 ApplicationContextInitializer 实现类,并创建实例  
  1-3. 扫描classpath:META-INF/spring.factories 文件中定义的 ApplicationListener 实现类,并创建实例  

*spring.factories加载的 ApplicationContextInitializer，ApplicationListener 在全局启动过程中具有非常高的运行优先级，并且ApplicationListener 会在 ApplicationContextInitializer前被触发调用，配置文件的加载解析也是在 ApplicationListener 中完成，后面会进行补充说明*

<br/>
<br/>

#### run方法启动过程

-----------  

```
public ConfigurableApplicationContext run(String... args) {
		StopWatch stopWatch = new StopWatch();
		stopWatch.start();
		ConfigurableApplicationContext context = null;
		Collection<SpringBootExceptionReporter> exceptionReporters = new ArrayList<>();
		configureHeadlessProperty();
		SpringApplicationRunListeners listeners = getRunListeners(args);  // 2-1
		listeners.starting();
		try {
			ApplicationArguments applicationArguments = new DefaultApplicationArguments(
					args);
			ConfigurableEnvironment environment = prepareEnvironment(listeners,
					applicationArguments);
			configureIgnoreBeanInfo(environment);
			Banner printedBanner = printBanner(environment);
			context = createApplicationContext();
			exceptionReporters = getSpringFactoriesInstances(
					SpringBootExceptionReporter.class,
					new Class[] { ConfigurableApplicationContext.class }, context);
			prepareContext(context, environment, listeners, applicationArguments,
					printedBanner);
			refreshContext(context);
			afterRefresh(context, applicationArguments);
			stopWatch.stop();
			if (this.logStartupInfo) {
				new StartupInfoLogger(this.mainApplicationClass)
						.logStarted(getApplicationLog(), stopWatch);
			}
			listeners.started(context);
			callRunners(context, applicationArguments);
		}
		catch (Throwable ex) {
			handleRunFailure(context, ex, exceptionReporters, listeners);
			throw new IllegalStateException(ex);
		}

		try {
			listeners.running(context);
		}
		catch (Throwable ex) {
			handleRunFailure(context, ex, exceptionReporters, null);
			throw new IllegalStateException(ex);
		}
		return context;
	}
```

<br/>

  2-1. 扫描classpath:META-INF/spring.factories 文件中定义的 SpringApplicationRunListener 实现类,并创建实例,然后将实例组合到 SpringApplicationRunListeners 实例中，普通web应用默认情况下其实只是加载了一个 EventPublishingRunListener 实例，该实例在启动过程中会用来发送各类事件给监听器 (listeners.starting() 触发了一个 ApplicationStartingEvent 事件,这时就已经可以触发前面初始化加载的ApplicationListener监听器了)

  <br/>
  <br/>
  <br/>
