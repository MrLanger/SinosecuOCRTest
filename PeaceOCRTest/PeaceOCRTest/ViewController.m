//
//  ViewController.m
//  PeaceOCRTest
//
//  Created by HENING on 2018/5/25.
//  Copyright © 2018年 HeNing. All rights reserved.
//

#import "ViewController.h"
#import<AVFoundation/AVCaptureDevice.h>
#import <AVFoundation/AVMediaFormat.h>
#import<AssetsLibrary/AssetsLibrary.h>
#import <Photos/Photos.h>

#define iOS8Later ([UIDevice currentDevice].systemVersion.floatValue >= 8.0f)

@interface ViewController ()<UIImagePickerControllerDelegate,UINavigationControllerDelegate, NSXMLParserDelegate>

@property(nonatomic,strong) UIImagePickerController *imagePicker;
@property (weak, nonatomic) IBOutlet UIImageView *showImageView;
@property (weak, nonatomic) IBOutlet UILabel *resaultLabel;

// xml解析后的字典
@property(nonatomic,strong) NSMutableDictionary *dataDic;
// 用来记录当前xml解析的节点名称
@property (nonatomic, copy) NSString *currentElementName;
// 用来记录当前xml解析的节点value
@property (nonatomic, copy) NSString *currentValueName;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (UIImagePickerController *)imagePicker{
    if (!_imagePicker) {
        _imagePicker = [[UIImagePickerController alloc] init];
        _imagePicker.delegate = self; //设置代理
        _imagePicker.allowsEditing = YES;
    }
    return _imagePicker;
}

- (IBAction)openPhotoLibrary:(id)sender {
    UIAlertController *sheetCtr = [UIAlertController alertControllerWithTitle:@"选择文件" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *cameraAction = [UIAlertAction actionWithTitle:@"拍照" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
        self.imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        [self presentViewController:self.imagePicker animated:YES completion:nil];
    }];
    
    UIAlertAction *photoLibraryAction = [UIAlertAction actionWithTitle:@"相册" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        self.imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentViewController:self.imagePicker animated:YES completion:nil];
    }];
    [sheetCtr addAction:cancelAction];
    [sheetCtr addAction:cameraAction];
    [sheetCtr addAction:photoLibraryAction];
    [self presentViewController:sheetCtr animated:YES completion:nil];
}

#pragma mark -实现图片选择器代理
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info{
    [picker dismissViewControllerAnimated:YES completion:nil];
    UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage]; //通过key值获取到图片
    self.showImageView.image = image;
    
    // 证件类型;二代证 2;行驶证 6;驾照 5;银行卡 17;车牌 19;
    NSString *requestType = @"19";
    
    NSData *data = UIImageJPEGRepresentation(image, 1.0f);
    NSString *imgBase64Str = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    NSString *paramdata = [NSString stringWithFormat:@"%@==##%@==##==##null", imgBase64Str, requestType];
    
    NSMutableDictionary *parameters = [[NSMutableDictionary alloc]init];
    [parameters setObject:@"test" forKey:@"username"];
    [parameters setObject:@"NULL" forKey:@"signdata"];
    [parameters setObject:@"jpeg" forKey:@"imgtype"];
    [parameters setObject:paramdata forKey:@"paramdata"];
    
    [self postRequest:parameters];
}

- (void)postRequest:(NSDictionary *)parameters{
    // 1.创建请求
    NSURL *url = [NSURL URLWithString:@"http://192.168.10.9:8080/cxfServerX/doAllCardRecon"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // 2.设置请求体 NSDictionary --> NSData
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:parameters options:NSJSONWritingPrettyPrinted error:nil];
    
    // 3.发送请求
    __weak __typeof(&*self)weakSelf = self;
    NSURLSessionDataTask *dataTask = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        __strong __typeof(&*self)strongSelf = weakSelf;
        
        //解析xml文件
        NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:data];
        xmlParser.delegate = strongSelf;
        [xmlParser parse];
        
        NSString *str = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
        NSLog(@"%lu", (unsigned long)data.length);
        NSLog(@"request：\n %@", str);
    }];
    
    [dataTask resume];
}

# pragma mark - 协议方法

// 开始
- (void)parserDidStartDocument:(NSXMLParser *)parser {
    NSLog(@"开始");
    self.dataDic = [NSMutableDictionary dictionary];
}

// 获取节点头
- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName attributes:(NSDictionary<NSString *,NSString *> *)attributeDict {
    NSLog(@"start element : %@", elementName);
    _currentElementName = elementName;
    _currentValueName = @"";
    if ([elementName isEqualToString:@"item"]) {
        _currentElementName = attributeDict[@"desc"];
    }
}

// 获取节点的值 (这个方法在获取到节点头和节点尾后，会分别调用一次)
- (void)parser:(NSXMLParser *)parser foundCharacters:(NSString *)string {
    NSLog(@"value : %@", string);
    if ([string containsString:@"\n"]||[string containsString:@"\t"]) {
    }else{
        _currentValueName = [NSString stringWithFormat:@"%@ %@", _currentValueName, string];
    }
}

// 获取节点尾
- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName {
    
    NSLog(@"end element :%@", elementName);
    NSString *value = [self replaceString:_currentValueName];
    
    [self.dataDic setObject:value forKey:_currentElementName];
}

// 结束
- (void)parserDidEndDocument:(NSXMLParser *)parser {
    NSLog(@"%@", self.dataDic);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __block NSString *text = @"识别结果：";
        [self.dataDic enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            text = [NSString stringWithFormat:@"%@ \n %@ : %@", text, key, obj];
        }];
        self.resaultLabel.text = text;
    });
}

// 正则去掉制表符
- (NSString *)replaceString:(NSString *)string{
    
    NSRegularExpression *regularExpression = [NSRegularExpression regularExpressionWithPattern: @"\\[{2}.*?\\]{2}" options:0 error:nil];
    string  = [regularExpression stringByReplacingMatchesInString:string options:0 range:NSMakeRange(0, string.length) withTemplate:@""];
    return string;
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self authorizationStatusAuthorized];
}

/// 相册授权
- (BOOL)authorizationStatusAuthorized {
    NSInteger status = [self authorizationStatus];
    if (status == 0) {
        /**
         * 当某些情况下AuthorizationStatus == AuthorizationStatusNotDetermined时，无法弹出系统首次使用的授权alertView，系统应用设置里亦没有相册的设置，此时将无法使用，故作以下操作，弹出系统首次使用的授权alertView
         */
        [self requestAuthorizationWithCompletion];
    }
    
    return status == 3;
}

- (NSInteger)authorizationStatus {
    if (iOS8Later) {
        return [PHPhotoLibrary authorizationStatus];
    } else {
        return [ALAssetsLibrary authorizationStatus];
    }
    return NO;
}

- (void)requestAuthorizationWithCompletion {
    if (iOS8Later) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
            }];
        });
    } else {
        ALAssetsLibrary *assetLibrary = [[ALAssetsLibrary alloc] init];
        [assetLibrary enumerateGroupsWithTypes:ALAssetsGroupAll usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        } failureBlock:^(NSError *error) {
        }];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
