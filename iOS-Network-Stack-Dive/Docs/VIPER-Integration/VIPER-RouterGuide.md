# VIPER 路由层指南

## 1. 路由类型说明
| 路由类型枚举值              | 使用场景                   | 对应处理器协议           |
|------------------------------|---------------------------|--------------------------|
| TJPNavigationRouteTypeViewPush    | 常规视图压栈跳转          | TJPViewPushHandler |
| TJPNavigationRouteTypeViewPresent | 模态呈现视图              | TJPViewPresentHandler |
| TJPNavigationRouteTypeServiceCall | 后台服务调用              | TJPServiceHandler        |
| TJPNavigationRouteTypeHybrid      | 混合跳转（视图+服务组合） | TJPHybridHandler         |

## 2. 参数格式规范
### 视图跳转参数模板
```objc
    NSDictionary *params = @{
        @"viewControllerClass": @"MessageDetailViewController",
        @"navigationType": @(TJPNavigationTypePush),
        @"messageId": self.messageId,
        @"timestamp": @([[NSDate date] timeIntervalSince1970])
    };
    
    return [TJPNavigationModel modelWithRouteID:@"message/detail"
                                    parameters:params];


