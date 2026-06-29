# refresh方法
```JAVA
@Override
	public void refresh() throws BeansException, IllegalStateException {
		synchronized (this.startupShutdownMonitor) {
		    // 1.context 为刷新做准备
			// Prepare this context for refreshing.
			prepareRefresh();

			// Tell the subclass to refresh the internal bean factory.
			// 2.让子类实现刷新内部持有BeanFactory
			ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

			// Prepare the bean factory for use in this context.
			// 3.对beanFactory做一些准备工作：注册一些context回调、bean等
			prepareBeanFactory(beanFactory);

			try {
				// Allows post-processing of the bean factory in context subclasses.
				// 4.调用留给子类来提供实现逻辑的 对BeanFactory进行处理的钩子方法
				postProcessBeanFactory(beanFactory);

				// Invoke factory processors registered as beans in the context.
				// 5.执行context中注册的 BeanFactoryPostProcessor bean
				invokeBeanFactoryPostProcessors(beanFactory);

				// Register bean processors that intercept bean creation.
				// 6.注册BeanPostProcessor: 获得用户注册的BeanPostProcessor实例，注册到BeanFactory上
				registerBeanPostProcessors(beanFactory);

				// Initialize message source for this context.
				// 7.初始化国际化资源
				initMessageSource();

				// Initialize event multicaster for this context.
				// 8.初始化Application event 广播器
				initApplicationEventMulticaster();

				// Initialize other special beans in specific context subclasses.
				// 9.执行 有子类来提供实现逻辑的钩子方法 onRefresh
				onRefresh();

				// Check for listener beans and register them.
				// 10.注册ApplicationListener: 获得用户注册的ApplicationListener Bean实例，注册到广播器上
				registerListeners();

				// Instantiate all remaining (non-lazy-init) singletons.
				// 11、完成剩余的单例Bean的实例化
				finishBeanFactoryInitialization(beanFactory);

				// Last step: publish corresponding event.
				// 12 发布对应的事件
				finishRefresh();
			}

			catch (BeansException ex) {
				if (logger.isWarnEnabled()) {
					logger.warn("Exception encountered during context initialization - " +
							"cancelling refresh attempt: " + ex);
				}

				// Destroy already created singletons to avoid dangling resources.
				destroyBeans();

				// Reset 'active' flag.
				cancelRefresh(ex);

				// Propagate exception to caller.
				throw ex;
			}

			finally {
				// Reset common introspection caches in Spring's core, since we
				// might not ever need metadata for singleton beans anymore...
				resetCommonCaches();
			}
		}
	}
```

# Bean的生命周期
BeanFactoryProcessor
InstantiationAware
构造实例化Bean
属性注入
xxxAware发放
BeanPostProcessor

- 创建
    
    - BeanFactoryPostProcesser#postProcessBeanFactory() #bean工厂的前置处理发放
        
    - InstantiationAwareBeanPostProcessorAdapter#postProcessBeforeInstantiation() #实例化感知bean前置处理在bean实例化之前
        
    - 构造器实例化bean #bean构造器实例化
        
    - InstantiationAwareBeanPostProcessAdapter#postProcessAfterInstantiation() #实例化感知bean的bean实例化后置处理
        
    - InstantiationAwareBeanPostProcessAdapter#postPropertyValues() #实例化感知bean的属性注入前置处理
        
    - 注入Bean属性 
        
    - XXXAware的方法
        
        - BeanNameAware#setBeanName()
            
        - BeanFacoryAware#setBeanFactory()
            
    - BeanPostProcessor#postProcessBeforeInitialization() 
        
    - init-method
        
    - @PostConstruct
        
    - InitializingBean#afterPropertiesSet()
        
    - BeanPostProcessor#postProcessAfterInitialization()
        
- 销毁
    
    - DisposabledBean#destory()
        
    - destory-method
        
    - @PreDestory