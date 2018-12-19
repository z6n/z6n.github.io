+++
title = "Spring Boot 源码分析-启动流程(1)"
description = ""
tags = [
    "java",
    "spring boot",
    "sources"
]
date = "2018-12-17 20:19:48.287 +0800"
categories = [
    "java"
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

  2-1. 扫描classpath:META-INF/spring.factories 文件中定义的 SpringApplicationRunListener 实现类,并创建实例,然后将实例组合到 SpringApplicationRunListeners 实例中，普通web应用默认情况下其实只是加载了一个 EventPublishingRunListener 实例，该实例在启动过程中会使用(SimpleApplicationEventMulticaster)来发送各类事件给监听器  
  listeners.starting() 触发了一个 ApplicationStartingEvent 事件,这时就已经可以触发前面初始化加载的ApplicationListener监听器了

<br/>

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

  2-2-6. SpringConfigurationPropertySources PropertySourcesPlaceholdersResolver 及2-2-3处的PropertySources绑定到一起用于后的属性获取包括将表达式解析成最终值 如 `server.port=${random.int[8080,8090]}`  

<br/>

2-3. configureIgnoreBeanInfo(environment) 在System.setProperty 中如果不存在 "spring.beaninfo.ignore" 则设置该属性，默认为true

<br/>

2-4. createApplicationContext() 会根据 WebApplicationType 来创建 ConfigurableApplicationContext 的实例。 如 WebApplicationType 为 SERVLET 将创建 `org.springframework.boot.web.servlet.context.AnnotationConfigServletWebServerApplicationContext` 的实例。  
此时需要注意在 AnnotationConfigServletWebServerApplicationContext 被创建时 属性中 environment 将被创建一个新的 Environment 实例，该实例这时并非为 2-2 中所创建的 Environment。AnnotationConfigServletWebServerApplicationContext 中 初始化了两个关键类 [AnnotatedBeanDefinitionReader, ClassPathBeanDefinitionScanner]  
在创建 AnnotatedBeanDefinitionReader 时通过`AnnotationConfigUtils.registerAnnotationConfigProcessors(this.registry)` 将如下类交由beanFactory托管  
```
org.springframework.context.annotation.internalConfigurationAnnotationProcessor: org.springframework.context.annotation.ConfigurationClassPostProcessor  
org.springframework.context.annotation.internalAutowiredAnnotationProcessor: org.springframework.beans.factory.annotation.AutowiredAnnotationBeanPostProcessor
org.springframework.context.annotation.internalCommonAnnotationProcessor: org.springframework.context.annotation.CommonAnnotationBeanPostProcessor
org.springframework.context.annotation.internalPersistenceAnnotationProcessor: org.springframework.orm.jpa.support.PersistenceAnnotationBeanPostProcessor
org.springframework.context.event.internalEventListenerProcessor: org.springframework.context.event.EventListenerMethodProcessor
org.springframework.context.event.internalEventListenerFactory: org.springframework.context.event.DefaultEventListenerFactory
```
创建 ClassPathBeanDefinitionScanner 时初始化了 AnnotationTypeFilter （用户匹配元注解）

<br/>

2-5. 这里比较简单，主要是扫描classpath:META-INF/spring.factories 文件中定义的 SpringBootExceptionReporter 实现类并初始化，这些类用于处理启动过程中的错误

<br/>

2-6. 这一步主要包含如下几个重要步骤  

2-6-1. 将在 2-4 中所创建的 AnnotationConfigServletWebServerApplicationContext 的 environment属性替换为 2-2-1 中所创建的 Environment 实例  

2-6-2. 这里主要是将前面 2-2-2 中创建的 ConversionService 设置到 context.beanFactory.conversionService 中

2-6-3. 前面1-2中通过扫描classpath:META-INF/spring.factoriesApplicationContextInitializer将在这一步被调用  

2-6-4. 触发 ApplicationContextInitializedEvent 事件(此时因还未refresh context加载bean 所以该事件还是只有 spring.factories 文件中扫描加载的的ApplicationListener能监听到)  

2-6-5. 将启动命令的args封装成的 ApplicationArguments 注入到context 的 beanFactory 中,并设置 beanFactory 的一些属性配置  

2-6-6. 通过启动入口sources(1处传入的class)作为参数创建了 BeanDefinitionLoader 。 BeanDefinitionLoader在创建过程中同样会创建 [AnnotatedBeanDefinitionReader, ClassPathBeanDefinitionScanner] 这与 2-4 中的实例并不相同，但 2-4 已经在`AnnotationConfigUtils.registerAnnotationConfigProcessors(this.registry)` 注入了一些关键类，这里不会重复注入
创建ClassPathBeanDefinitionScanner添加了排除过滤器 ClassExcludeFilter(sources)  
然后通过调用BeanDefinitionLoader.load() 方法 将入口Class加入到context beanFactory托管

2-6-7. 触发 ApplicationPreparedEvent 事件。此处触发事件前做了一些额外的工作。  
将循环判断从 spring.factories 文件中扫描加载的的 ApplicationListener 或者 在创建 SpringApplication 手动设置的 ApplicationListener （存储在SpringApplication.listeners中），如果listener实现了 ApplicationContextAware 接口，将会把context设置到listener实例属性中。  
将listener加入到 context 的 applicationListeners 属性中。


<br/>

2-7. refreshContext(context)应该是处理最复杂的一步了，各种托管bean的初始化,扫描,加载,装配都在这一步完成，后面用专门文章针对这一方法做仔细说明.  

<br/>

2-8. afterRefresh 为一个空方法，并未做任何实现

<br/>

2-9. 触发 ApplicationStartedEvent 事件,这里也有些不同，前面都是通过EventPublishingRunListener.SimpleApplicationEventMulticaster 来触发，这里会使用context中的SimpleApplicationEventMulticaster来触发，这时因各种bean已经在2-7已经初始化完成，所以实现了相应监听接口的类都能得到触发。

<br/>

2-10. 启动完成后从context中调用 ApplicationRunner, CommandLineRunner 调用执行

<br/>

2-11. 通过调用 context 触发 ApplicationReadyEvent 事件  



<br/>
<br/>

### 总结
-------------------

到这里只是简单的介绍了下spring boot的启动过程，说明了再启动前做了哪些事，我们能从这些事情中能做到哪些切入点,可以从哪一步来定义自己的功能，或者出现问题能判断出大致出现在哪一步。 从上面我们可以看到我们能做的最早的切入点便是 ApplicationListener， ApplicationListener触发执行时，应用bean此时还并未进入初始化状态。所以我们可以用 ApplicationListener 来做很多的准备工作，比如改写配置，实现自己的配置属性加载类等。而且我们可以看出在2-7之前所触发的事件只有在spring.factories中定义的或者在程序创建时加入的listener能够监听到(如 ApplicationStartingEvent, ApplicationPreparedEvent)，只有在2-7完成后触发的事件采用spring常用注解托管的监听器才能监听到...

<br/>
<br/>

**待续...**

  <br/>
  <br/>
  <br/>
