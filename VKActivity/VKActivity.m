//
//  VKontakteActivity.m
//  VKActivity
//
//  Created by Denivip Group on 28.01.14.
//  Copyright (c) 2014 Denivip Group. All rights reserved.
//

#import "VKActivity.h"
#import "VKSdk.h"
#import "MBProgressHUD.h"
#import "REComposeViewController.h"

@interface VKActivity () <VKSdkDelegate, REComposeViewControllerDelegate>
@property (nonatomic, strong) UIImage *image;
@property (nonatomic, strong) NSString *string;
@property (nonatomic, strong) NSURL *URL;
@property (nonatomic, strong) UIViewController *parent;
@property (nonatomic, strong) MBProgressHUD *HUD;
@end

@implementation VKActivity

#pragma mark - NSObject

- (id)init
{
    NSAssert(NO, @"You cannot init this class directly. Instead, use initWithParent");
    return nil;
}

- (id)initWithParent:(UIViewController *)parent
{
    self = [super init];
    
    if (self) {
        self.parent = parent;
    }
    
    return self;
}

#pragma mark - UIActivity

- (NSString *)activityType
{
    return @"VKActivityTypeVKontakte";
}

- (NSString *)activityTitle
{
    return @"VK";
}

- (UIImage *)activityImage
{
    return [UIImage imageNamed:@"vk_activity"];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_7_0
+ (UIActivityCategory)activityCategory
{
    return UIActivityCategoryShare;
}
#endif

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems
{
    for (UIActivityItemProvider *item in activityItems) {
        if ([item isKindOfClass:[UIImage class]]) {
            return YES;
        }
        else if ([item isKindOfClass:[NSString class]]){
            return YES;
        }
        else if ([item isKindOfClass:[NSURL class]]){
            return YES;
        }
    }
    return NO;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems
{
    for (id item in activityItems) {
        if ([item isKindOfClass:[NSString class]]) {
            self.string = self.string ? [NSString stringWithFormat:@"%@ %@", self.string, item] : item;
        }
        else if([item isKindOfClass:[UIImage class]]) {
            self.image = item;
        }
        else if([item isKindOfClass:[NSURL class]]) {
            self.URL = item;
        }
    }
}

- (void)performActivity
{
    [VKSdk instance].delegate = self;
    
    [self.parent dismissViewControllerAnimated:YES completion:^(void)
     {
         if ([VKSdk wakeUpSession]) {
             [self startComposeViewController];
         }
         else {
             [VKSdk authorize:@[VK_PER_WALL, VK_PER_PHOTOS] revokeAccess:NO forceOAuth:NO inApp:YES display:VK_DISPLAY_IOS];
         }
     }];
}

- (void)activityDidFinish:(BOOL)completed
{
    [super activityDidFinish:completed];
    
    [VKSdk instance].delegate = nil;
}

#pragma mark - Upload

- (void)postToWall
{
    if (self.image) {
        [self uploadPhoto];
    }
    else {
        [self uploadText];
    }
}

- (void)uploadPhoto
{
    NSString *userId = [VKSdk getAccessToken].userId;
    VKRequest *request = [VKApi uploadWallPhotoRequest:self.image
                                            parameters:[VKImageParameters jpegImageWithQuality:1.f]
                                                userId:[userId integerValue]
                                               groupId:0];
    
	[request executeWithResultBlock: ^(VKResponse *response) {
	    VKPhoto *photoInfo = [(VKPhotoArray*)response.parsedModel objectAtIndex:0];
	    NSString *photoAttachment = [NSString stringWithFormat:@"photo%@_%@", photoInfo.owner_id, photoInfo.id];
        [self postToWall:@{ VK_API_ATTACHMENTS : photoAttachment,
                            VK_API_FRIENDS_ONLY : @(0),
                            VK_API_OWNER_ID : userId,
                            VK_API_MESSAGE : [NSString stringWithFormat:@"%@ %@",self.string, [self.URL absoluteString]]}];
    } errorBlock: ^(NSError *error) {
	    NSLog(@"Error: %@", error);
        [self activityDidFinish:NO];
	}];
}

- (void)uploadText
{
    [self postToWall:@{ VK_API_FRIENDS_ONLY : @(0),
                        VK_API_OWNER_ID : [VKSdk getAccessToken].userId,
                        VK_API_MESSAGE : [NSString stringWithFormat:@"%@\n%@",self.string, [self.URL absoluteString]]}];
}

- (void)postToWall:(NSDictionary *)params
{
    VKRequest *post = [[VKApi wall] post:params];
    
    [post executeWithResultBlock: ^(VKResponse *response) {
        [self activityDidFinish:YES];
    } errorBlock: ^(NSError *error) {
        NSLog(@"Error: %@", error);
        [self activityDidFinish:NO];
    }];
}

#pragma mark - vkSdk

- (void)vkSdkNeedCaptchaEnter:(VKError *)captchaError
{
	VKCaptchaViewController *vc = [VKCaptchaViewController captchaControllerWithError:captchaError];
	[vc presentIn:self.parent];
}

- (void)vkSdkTokenHasExpired:(VKAccessToken *)expiredToken
{
    [VKSdk authorize:@[VK_PER_WALL, VK_PER_PHOTOS] revokeAccess:NO forceOAuth:NO inApp:YES display:VK_DISPLAY_IOS];
}

-(void)vkSdkReceivedNewToken:(VKAccessToken *)newToken
{
    [self startComposeViewController];
}

- (void)vkSdkShouldPresentViewController:(UIViewController *)controller
{
	[self.parent presentViewController:controller animated:YES completion:nil];
}

- (void)vkSdkDidAcceptUserToken:(VKAccessToken *)token
{
    [self startComposeViewController];
}

- (void)vkSdkUserDeniedAccess:(VKError *)authorizationError
{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Access denied"
                                                       delegate:nil
                                              cancelButtonTitle:@"Close"
                                              otherButtonTitles:nil];
    [alertView show];
    
    [self activityDidFinish:NO];
}

- (void)startComposeViewController
{
    REComposeViewController *composeViewController = [[REComposeViewController alloc] init];
    composeViewController.title = @"VK";
    composeViewController.hasAttachment = YES;
    composeViewController.attachmentImage = self.image;
    composeViewController.text = self.string;
    [composeViewController setDelegate:self];
    [composeViewController presentFromRootViewController];
}

- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result
{
    [composeViewController dismissViewControllerAnimated:YES completion:nil];
    
    if (result == REComposeResultCancelled) {
        [self activityDidFinish:NO];
    }
    
    if (result == REComposeResultPosted) {
        self.string = composeViewController.text;
        [self postToWall];
    }
}

@end

