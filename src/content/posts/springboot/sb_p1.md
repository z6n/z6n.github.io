+++
title = "Spring Boot 源码分析(1)"
description = ""
tags = [
    "spring boot",
    "sources"
]
date = "2018-12-17 20:19:48.287 +0800"
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
					applicationArguments);    // 2-2
			configureIgnoreBeanInfo(environment); // 2-3
			Banner printedBanner = printBanner(environment);
			context = createApplicationContext();  // 2-4
			exceptionReporters = getSpringFactoriesInstances(
					SpringBootExceptionReporter.class,
					new Class[] { ConfigurableApplicationContext.class }, context);  // 2-5
			prepareContext(context, environment, listeners, applicationArguments,
					printedBanner);    // 2-6
			refreshContext(context);    // 2-7
			afterRefresh(context, applicationArguments);    // 2-8
			stopWatch.stop();
			if (this.logStartupInfo) {
				new StartupInfoLogger(this.mainApplicationClass)
						.logStarted(getApplicationLog(), stopWatch);
			}
			listeners.started(context);  // 2-9
			callRunners(context, applicationArguments);  // 2-10
		}
		catch (Throwable ex) {
			handleRunFailure(context, ex, exceptionReporters, listeners);
			throw new IllegalStateException(ex);
		}

		try {
			listeners.running(context);    // 2-11
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

  2-2. 主要做了如下几件事(只做简单描述，后面再做详细解刨)  

  2-2-1. 根据前面判断的程序类型 WebApplicationType 创建对应的Environment实例  

  2-2-2. 初始化和设置 ConversionService (用于各种类型的转换)  

  2-2-3. 配置 MutablePropertySources 将命令行参数加入到属性最前面，如果有的话.  
     (StandardServletEnvironment 在创建实例时就默认加载了  
       [StubPropertySource {name='servletConfigInitParams'},  
     StubPropertySource {name='servletContextInitParams'},  
     MapPropertySource {name='systemProperties'},  
     SystemEnvironmentPropertySource {name='systemEnvironment'}])

  2-2-4. 通过上一步加载的PropertySources 来设置 ActiveProfiles  

  2-2-5. 通过 SpringApplicationRunListeners 触发ApplicationEnvironmentPreparedEvent 事件  
    (用于加载配置文件的监听类 ConfigFileApplicationListener 便是监听了该事件，yml或properties配置文件便是在这时加载到环境中)
    
  2-2-6. SpringConfigurationPropertySources PropertySourcesPlaceholdersResolver 及3处的PropertySources绑定到一起用于后的属性获取包括将表达式解析成最终值 如 `server.port=${random.int[8080,8090]}`  

<br/>
<br/>

### 总结
-------------------

到这里只是简单的介绍了下spring boot的预启动过程，说明了再启动前做了哪些事，我们能从这些事情中能做到哪些切入点。 从上面我们可以看到我们能做的最早的切入点便是 ApplicationListener， ApplicationListener触发执行时，应用bean此时还并未进入初始化状态。所以我们可以用 ApplicationListener 来做很多的准备工作，比如改写配置，实现自己的配置属性加载类等。

<br/>
<br/>

**待续...**

  <br/>
  <br/>
  <br/>
