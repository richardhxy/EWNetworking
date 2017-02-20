//
//  EWNetworking.m
//  EWNetworking
//
//  Created by xyhuang2 on 17/2/8.
//  Copyright © 2017年 feiying. All rights reserved.
//

#import "EWNetworking.h"
#import "AFNetworking.h"
#import <CommonCrypto/CommonDigest.h>

@interface NSString (md5)

+ (NSString *)networking_md5:(NSString *)string;

@end

@implementation NSString (md5)

+ (NSString *)networking_md5:(NSString *)string {
  if (string == nil || [string length] == 0) {
    return nil;
  }
  
  unsigned char digest[CC_MD5_DIGEST_LENGTH], i;
  CC_MD5([string UTF8String], (int)[string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], digest);
  NSMutableString *ms = [NSMutableString string];
  
  for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
    [ms appendFormat:@"%02x", (int)(digest[i])];
  }
  
  return [ms copy];
}

@end

///默认请求的HTTPHeader
static NSDictionary *ew_httpHeaders = nil;
///存储所有请求的数组
static NSMutableArray *ew_requestTasks;

static AFHTTPSessionManager *ew_sharedManager = nil;
///默认超时时间
static NSTimeInterval ew_timeout = 30.0f;

static AFNetworkReachabilityStatus ew_networkStatus;


@implementation EWNetworking

static NSString *cachePath() {
  return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/EWNetworkingCaches"];
}

+ (NSMutableArray *)allTasks {
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    if (ew_requestTasks == nil) {
      ew_requestTasks = [[NSMutableArray alloc] init];
    }
  });
  
  return ew_requestTasks;
}

#pragma mark - initialize

+ (AFHTTPSessionManager *)manager {
  @synchronized (self) {
    if (!ew_sharedManager) {
      [EWNetworking detectNetwork];
      AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
      manager.requestSerializer = [AFHTTPRequestSerializer serializer];
      manager.responseSerializer = [AFJSONResponseSerializer serializer];
      manager.requestSerializer.stringEncoding = NSUTF8StringEncoding;
      manager.responseSerializer.acceptableContentTypes = [NSSet setWithArray:@[@"application/json",
                                                                                @"text/html",
                                                                                @"text/json",
                                                                                @"text/plain",
                                                                                @"text/javascript",
                                                                                @"text/xml",
                                                                                @"image/*"]];

      for (NSString *key in ew_httpHeaders.allKeys) {
        if (ew_httpHeaders[key] != nil) {
          [manager.requestSerializer setValue:ew_httpHeaders[key] forHTTPHeaderField:key];
        }
      }
      //统一设置超时时间
      manager.requestSerializer.timeoutInterval = ew_timeout;
      manager.operationQueue.maxConcurrentOperationCount = 3;
      ew_sharedManager = manager;
    }
  }
  return ew_sharedManager;
}

#pragma mark - Private

///检测网络
+ (void)detectNetwork {
  AFNetworkReachabilityManager *reachabilityManager = [AFNetworkReachabilityManager sharedManager];
  
  [reachabilityManager startMonitoring];
  [reachabilityManager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
    ew_networkStatus = status;
  }];
}

///获取缓存
+ (id)getCahceResponseWithURL:(NSString *)url parameters:(id)params {
  id cacheData = nil;
  
  if (url) {
    // Try to get datas from disk
    NSString *directoryPath = cachePath();
    NSString *absoluteURL = [EWNetworking generateGETAbsoluteURL:url params:params];
    NSString *key = [NSString networking_md5:absoluteURL];
    NSString *path = [directoryPath stringByAppendingPathComponent:key];
    
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:path];
    if (data) {
      cacheData = data;
      NSLog(@"Read data from cache for url: %@\n",url);
    }
  }
  
  return cacheData;
}

///写入缓存
+ (void)cacheResponseObject:(id)responseObject requestURL:(NSString *)requestURL parameters:(id)params {
  if (requestURL && responseObject && ![responseObject isKindOfClass:[NSNull class]]) {
    NSString *directoryPath = cachePath();
    NSError *error = nil;
    //文件夹📂不存在
    if (![[NSFileManager defaultManager]fileExistsAtPath:directoryPath isDirectory:nil]) {
      //创建文件夹📂
      [[NSFileManager defaultManager]createDirectoryAtPath:directoryPath
                               withIntermediateDirectories:YES
                                                attributes:nil
                                                     error:&error];
      if (error) {
        NSLog(@"失败——创建网络缓存文件夹📂");
        return;
      }
    }
    
    NSString *absoluteURL = [EWNetworking generateGETAbsoluteURL:requestURL params:params];
    NSString *key = [NSString networking_md5:absoluteURL];
    NSString *path = [directoryPath stringByAppendingPathComponent:key];
    NSDictionary *dict = (NSDictionary *)responseObject;

    NSData *data = nil;
    if ([dict isKindOfClass:[NSData class]]) {
      data = responseObject;
    }
    else {
      data = [NSJSONSerialization dataWithJSONObject:dict
                                             options:NSJSONWritingPrettyPrinted
                                               error:&error];
    }
    if (data && !error) {
      BOOL isCacheOK = [[NSFileManager defaultManager]createFileAtPath:path contents:data attributes:nil];
      if (isCacheOK) {
        NSLog(@"成功——网络缓存至本地：%@",absoluteURL);
      }
      else {
        NSLog(@"失败——网络缓存至本地：%@,%@",absoluteURL,[error localizedDescription]);
      }
    }
  }
}

///从URL和参数来拼接整体URL，仅对一级字典结构起作用
+ (NSString *)generateGETAbsoluteURL:(NSString *)url params:(id)params {
  if (params == nil || ![params isKindOfClass:[NSDictionary class]] || [params count] == 0) {
    return url;
  }
  
  NSString *queries = @"";
  for (NSString *key in params) {
    id value = [params objectForKey:key];
    
    if ([value isKindOfClass:[NSDictionary class]]) {
      continue;
    } else if ([value isKindOfClass:[NSArray class]]) {
      continue;
    } else if ([value isKindOfClass:[NSSet class]]) {
      continue;
    } else {
      queries = [NSString stringWithFormat:@"%@%@=%@&",
                 (queries.length == 0 ? @"&" : queries),
                 key,
                 value];
    }
  }
  
  if (queries.length > 1) {
    queries = [queries substringToIndex:queries.length - 1];
  }
  
  if (([url hasPrefix:@"http://"] || [url hasPrefix:@"https://"]) && queries.length > 1) {
    if ([url rangeOfString:@"?"].location != NSNotFound
        || [url rangeOfString:@"#"].location != NSNotFound) {
      url = [NSString stringWithFormat:@"%@%@", url, queries];
    } else {
      queries = [queries substringFromIndex:1];
      url = [NSString stringWithFormat:@"%@?%@", url, queries];
    }
  }
  
  return url.length == 0 ? queries : url;
}

///返回数据解析函数
+ (id)tryToParseData:(id)responseData {
  if ([responseData isKindOfClass:[NSData class]]) {
    // 尝试解析成JSON
    if (responseData == nil) {
      return responseData;
    } else {
      NSError *error = nil;
      NSDictionary *response = [NSJSONSerialization JSONObjectWithData:responseData
                                                               options:NSJSONReadingMutableContainers
                                                                 error:&error];
      
      if (error != nil) {
        return responseData;
      } else {
        return response;
      }
    }
  } else {
    return responseData;
  }
}

+ (EWURLSessionTask *)_requestWithUrl:(NSString *)url
                           httpMethod:(NSInteger)httpMethod
                               params:(NSDictionary *)params
                             progress:(EWDownloadProgress)progress
                              success:(EWResponseSuccess)success
                              failure:(EWResponseFail)failure {
  AFHTTPSessionManager *manager = [EWNetworking manager];
  if (!url || url.length == 0) {
    NSParameterAssert(url);
    return nil;
  }
  
  EWURLSessionTask *session = nil;
  if (httpMethod == EWHTTPMethod_Get) {
    if (ew_networkStatus == AFNetworkReachabilityStatusUnknown ||  ew_networkStatus == AFNetworkReachabilityStatusNotReachable ) {
      id response = [EWNetworking getCahceResponseWithURL:url parameters:params];
      if (response) {
        if (success) {
          [EWNetworking successResponse:response callback:success];
        }
        return nil;
      }
    }
    session = [manager GET:url
                parameters:params
                  progress:^(NSProgress * _Nonnull downloadProgress) {
                    if (progress) {
                      progress(downloadProgress.completedUnitCount,downloadProgress.totalUnitCount);
                    }
                  }
                   success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                     [EWNetworking successResponse:responseObject callback:success];
                     [EWNetworking cacheResponseObject:responseObject requestURL:url parameters:params];
                     [[EWNetworking allTasks] removeObject:task];
                   }
                   failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                     [[EWNetworking allTasks] removeObject:task];
                     if ([error code] < 0) {
                       id response = [EWNetworking getCahceResponseWithURL:task.originalRequest.URL.relativeString
                                                                parameters:params];
                       if (response) {
                         if (success) {
                           [EWNetworking successResponse:response callback:success];
                         }
                       }
                       else {
                         [EWNetworking failureWithError:error callback:failure];
                       }
                     }
                     else {
                       [EWNetworking failureWithError:error callback:failure];
                     }
                   }];
  }
  else if (httpMethod == EWHTTPMethod_Post){
    //POST请求不做缓存
    session = [manager POST:url
                 parameters:params
                   progress:^(NSProgress * _Nonnull uploadProgress) {
                     if (progress) {
                       progress(uploadProgress.completedUnitCount,uploadProgress.totalUnitCount);
                     }
                   }
                    success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
                      [EWNetworking successResponse:responseObject callback:success];
                      [[EWNetworking allTasks] removeObject:task];
                    }
                    failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
                      [[EWNetworking allTasks] removeObject:task];
                      [EWNetworking failureWithError:error callback:failure];
                    }];
  }
  
  
  if (session) {
    [[EWNetworking allTasks]addObject:session];
  }
  return session;
}

///成功的block回调
+ (void)successResponse:(id)responseData callback:(EWResponseSuccess)success {
  if (success) {
    success([EWNetworking tryToParseData:responseData]);
  }
}

///失败的block回调
+ (void)failureWithError:(NSError *)error callback:(EWResponseFail)failure {
  //不处理cancel过请求
  if ([error code] != NSURLErrorCancelled) {
    if (failure) {
      failure(error);
    }
  }
}


#pragma mark - Public

+ (void)clearAllCaches {
  [[NSFileManager defaultManager]
   removeItemAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@"Documents/EWNetworkingCaches"]
   error:nil];
}

+ (void)setSecurityPolicyWithCersPath:(NSArray<NSString *> *)cersPath {
  if (!ew_sharedManager) {
    ew_sharedManager = [EWNetworking manager];
  }
  NSMutableSet *cersData = [NSMutableSet set];
  [cersPath enumerateObjectsUsingBlock:^(NSString *obj, NSUInteger idx, BOOL *stop) {
    if (obj && obj.length != 0) {
      [cersData addObject:[NSData dataWithContentsOfFile:obj]];
    }
  }];
  AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate];
  securityPolicy.allowInvalidCertificates = YES;
  securityPolicy.validatesDomainName = NO;
  securityPolicy.pinnedCertificates = cersData;
  [ew_sharedManager setSecurityPolicy:securityPolicy];
}

+ (void)configCommonHttpHeaders:(NSDictionary *)httpHeaders {
  ew_httpHeaders = httpHeaders;
  if (!ew_sharedManager) {
    ew_sharedManager = [EWNetworking manager];
  }
  for (NSString *key in ew_httpHeaders.allKeys) {
    if (ew_httpHeaders[key] != nil) {
      [ew_sharedManager.requestSerializer setValue:ew_httpHeaders[key] forHTTPHeaderField:key];
    }
  }
}

+ (void)cancelAllRequest {
  @synchronized(self) {
    [[EWNetworking allTasks] enumerateObjectsUsingBlock:^(EWURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
      if ([task isKindOfClass:[EWURLSessionTask class]]) {
        [task cancel];
      }
    }];
    
    [[EWNetworking allTasks] removeAllObjects];
  };

}

+ (void)cancelRequestWithURL:(NSString *)url {
  if (url == nil) {
    return;
  }
  
  @synchronized(self) {
    [[EWNetworking allTasks] enumerateObjectsUsingBlock:^(EWURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
      if ([task isKindOfClass:[EWURLSessionTask class]]
          && [task.currentRequest.URL.absoluteString hasSuffix:url]) {
        [task cancel];
        [[EWNetworking allTasks] removeObject:task];
        return;
      }
    }];
  };
}

+ (EWURLSessionTask *)getWithUrl:(NSString *)url
                           params:(NSDictionary *)params
                          success:(EWResponseSuccess)success
                             fail:(EWResponseFail)fail {
  return [EWNetworking _requestWithUrl:url httpMethod:EWHTTPMethod_Get params:params progress:nil success:success failure:fail];
}

+ (EWURLSessionTask *)postWithUrl:(NSString *)url
                            params:(NSDictionary *)params
                           success:(EWResponseSuccess)success
                              fail:(EWResponseFail)fail {
	  return [EWNetworking _requestWithUrl:url httpMethod:EWHTTPMethod_Post params:params progress:nil success:success failure:fail];
}

+ (EWURLSessionTask *)uploadWithImage:(UIImage *)image
                                   url:(NSString *)url
                              filename:(NSString *)filename
                                  name:(NSString *)name
                              mimeType:(NSString *)mimeType
                            parameters:(NSDictionary *)parameters
                              progress:(EWUploadProgress)progress
                               success:(EWResponseSuccess)success
                                  fail:(EWResponseFail)fail {
  if (!url || url.length == 0) {
    NSParameterAssert(url);
    return nil;
  }
  AFHTTPSessionManager *manager = [EWNetworking manager];
  EWURLSessionTask *session = [manager POST:url parameters:parameters constructingBodyWithBlock:^(id<AFMultipartFormData>  _Nonnull formData) {
    NSData *imageData = UIImageJPEGRepresentation(image, 1);
    NSString *imageFileName = filename;
    if (!filename || ![filename isKindOfClass:[NSString class]] || filename.length == 0) {
      NSDate *date = [[NSDate alloc]init];
      double timeStamp = [date timeIntervalSince1970];
      imageFileName = [NSString stringWithFormat:@"%f.jpg",timeStamp];
    }
    [formData appendPartWithFileData:imageData name:name fileName:imageFileName mimeType:mimeType];
  } progress:^(NSProgress * _Nonnull uploadProgress) {
    if (progress) {
      progress(uploadProgress.completedUnitCount,uploadProgress.totalUnitCount);
    }
  } success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
    [[EWNetworking allTasks] removeObject:task];
    [EWNetworking successResponse:responseObject callback:success];
  } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
    [[EWNetworking allTasks] removeObject:task];
    [EWNetworking failureWithError:error callback:fail];
  }];
  
  [session resume];
  if (session) {
    [[EWNetworking allTasks]addObject:session];
  }
  
  return session;
}

+ (EWURLSessionTask *)downloadWithUrl:(NSString *)url
                            saveToPath:(NSString *)saveToPath
                              progress:(EWDownloadProgress)progress
                               success:(EWResponseSuccess)success
                               failure:(EWResponseFail)failure {
  if (!url || url.length == 0) {
    NSParameterAssert(url);
    return nil;
  }
  NSURLRequest *downloadRequest = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
  AFHTTPSessionManager *manager = [EWNetworking manager];
  EWURLSessionTask *session = [manager downloadTaskWithRequest:downloadRequest progress:^(NSProgress * _Nonnull downloadProgress) {
    if (progress) {
      progress(downloadProgress.completedUnitCount,downloadProgress.totalUnitCount);
    }
  } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
    return [NSURL fileURLWithPath:saveToPath];
  } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
    [[EWNetworking allTasks] removeObject:session];
    if (!error) {
      if (success) {
        success(filePath.absoluteString);
      }
    }
    else {
      [EWNetworking failureWithError:error callback:failure];
    }
  }];
  
  [session resume];
  if (session) {
    [[self allTasks] addObject:session];
  }
  
  return session;
}



@end
