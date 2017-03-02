//
//  EWNetworking.h
//  EWNetworking
//
//  Created by xyhuang2 on 17/2/8.
//  Copyright © 2017年 feiying. All rights reserved.
//

//**********************version 1.7**************************//


#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

#if DEBUG
#define EWNetLog(format, ...) NSLog((@"[函数名:%s]" "[行号:%d]" "[Header:%@]" format), __FUNCTION__, __LINE__, [ew_httpHeaders description], ##__VA_ARGS__)
#define EWLog(...) NSLog(__VA_ARGS__)
#else
#define EWNetLog(format, ...)
#define EWLog(format, ...)
#endif

@class NSURLSessionTask;

typedef NSURLSessionTask EWURLSessionTask;
typedef void(^EWResponseSuccess)(id response);
typedef void(^EWResponseFail)(NSError *error);
///bytesWritten:已上传的大小;totalBytesWritten:总上传大小;
typedef void (^EWUploadProgress)(int64_t bytesWritten,int64_t totalBytesWritten);
///bytesRead:已下载的大小;totalBytesRead:文件总大小;
typedef void (^EWDownloadProgress)(int64_t bytesRead,int64_t totalBytesRead);

typedef NS_ENUM(NSInteger, EWHTTPMethod) {
  EWHTTPMethod_Get = 1,
  EWHTTPMethod_Post = 2,
};

@interface EWNetworking : NSObject

///更改缓存位置，默认放在 caches/default 文件夹下
+(void)changeCacheDirectory:(NSString *)directoryStr;

///删除所有缓存
+ (void)clearAllCaches;

///加证书文件Path的set
+ (void)setSecurityPolicyWithCersPath:(NSArray<NSString *> *)cersPath;

///配置公共的请求头，只调用一次即可，在应用启动的时候配置就可以了
+ (void)configCommonHttpHeaders:(NSDictionary *)httpHeaders;

///取消所有请求
+ (void)cancelAllRequest;

///取消某个请求，支持absoluteURL和relativeURL，采用suffix判断
+ (void)cancelRequestWithURL:(NSString *)url;

///
+ (EWURLSessionTask *)getWithUrl:(NSString *)url
                           params:(NSDictionary *)params
                          success:(EWResponseSuccess)success
                             fail:(EWResponseFail)fail;

/**
 *  post网络请求
 *
 *  @param url          请求的URL
 *  @param params       请求的参数
 *  @param success      成功的回调
 *  @param fail         失败的回调
 *
 *  @return 返回一个可以取消的网路请求
 */
+ (EWURLSessionTask *)postWithUrl:(NSString *)url
                            params:(NSDictionary *)params
                           success:(EWResponseSuccess)success
                              fail:(EWResponseFail)fail;

///image:图片对象;url:上传图片的接口路径;filename:给图片起一个名字;name:与指定的图片相关联的名称，这是由后端写接口的人指定的，如imagefiles;mimeType:默认为image/jpeg;
+ (EWURLSessionTask *)uploadWithImage:(UIImage *)image
                                   url:(NSString *)url
                              filename:(NSString *)filename
                                  name:(NSString *)name
                              mimeType:(NSString *)mimeType
                            parameters:(NSDictionary *)parameters
                              progress:(EWUploadProgress)progress
                               success:(EWResponseSuccess)success
                                  fail:(EWResponseFail)fail;

+ (EWURLSessionTask *)downloadWithUrl:(NSString *)url
                            saveToPath:(NSString *)saveToPath
                              progress:(EWDownloadProgress)progressBlock
                               success:(EWResponseSuccess)success
                               failure:(EWResponseFail)failure;


@end
