/*
 * Copyright (C) 2014 Catalyze, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

#import "AppDelegate.h"
#import "Catalyze.h"
#import "AWSCore.h"
#import "AWSSNS.h"

@interface AppDelegate()

@property (strong, nonatomic) UINavigationController *controller;
@property (strong, nonatomic) SignInViewController *signInViewController;
@property (strong, nonatomic) ConversationListViewController *conversationListViewController;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:kConversations]) {
        [[NSUserDefaults standardUserDefaults] setObject:[NSArray array] forKey:kConversations];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    _signInViewController = [[SignInViewController alloc] initWithNibName:nil bundle:nil];
    _signInViewController.delegate = self;
    _controller = [[UINavigationController alloc] initWithRootViewController:_signInViewController];
    self.window.rootViewController = _controller;
    
    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [application registerUserNotificationSettings:settings];
    [application registerForRemoteNotifications];
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [Catalyze setApiKey:API_KEY applicationId:APP_ID];
    [Catalyze setLoggingLevel:kLoggingLevelDebug];
    
    UILocalNotification *note = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (note) {
        // we opened the app by tapping on a notification
        //application.applicationIconBadgeNumber = note.applicationIconBadgeNumber-1;
    }
    application.applicationIconBadgeNumber = 0;
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application {
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application {
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application {
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    NSString *deviceTokenString = [[[deviceToken description] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"<>"]] stringByReplacingOccurrencesOfString:@" " withString:@""];
    [[NSUserDefaults standardUserDefaults] setObject:deviceTokenString forKey:kDeviceToken];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"failed to register for push notifications %@", error.localizedDescription);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSMutableSet *unread = [NSMutableSet setWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:kConversations]];
    NSString *conversationId = [userInfo valueForKey:kConversationId];
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive && _handler) {
        [_handler handleNotification:conversationId];
    } else {
        [unread addObject:conversationId];
        [[NSUserDefaults standardUserDefaults] setObject:[unread allObjects] forKey:kConversations];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    application.applicationIconBadgeNumber = unread.count;
}

#pragma mark - SignInDelegate

- (void)signInSuccessful {
    [_signInViewController.view endEditing:YES];
    _signInViewController.txtPhoneNumber.text = @"";
    _signInViewController.txtPassword.text = @"";
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc] initWithRegionType:AWSRegionUSEast1 identityPoolId:IDENTITY_POOL_ID];
        
        AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:AWSRegionUSEast1
                                                                             credentialsProvider:credentialsProvider];
        
        [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
        
        AWSSNS *sns = [AWSSNS defaultSNS];
        AWSSNSCreatePlatformEndpointInput *request = [AWSSNSCreatePlatformEndpointInput new];
        request.token = [[NSUserDefaults standardUserDefaults] valueForKey:kDeviceToken];
        request.platformApplicationArn = APPLICATION_ARN;
        request.customUserData = [[CatalyzeUser currentUser] username]; // most likely will be nil here, but set it anyway
        [[sns createPlatformEndpoint:request] continueWithBlock:^id(AWSTask *task) {
            if (task.error) {
                NSLog(@"Error: %@",task.error);
            } else {
                AWSSNSCreateEndpointResponse *createEndPointResponse = task.result;
                NSLog(@"endpointArn: %@",createEndPointResponse);
                [[NSUserDefaults standardUserDefaults] setObject:createEndPointResponse.endpointArn forKey:kEndpointArn];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
            return nil;
        }];
    });
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UISplitViewController *split = [[UISplitViewController alloc] init];
        _conversationListViewController = [[ConversationListViewController alloc] initWithNibName:nil bundle:nil];
        
        ConversationViewController *conversationViewController = [[ConversationViewController alloc] initWithNibName:nil bundle:nil];
        
        UINavigationController *master = [[UINavigationController alloc] initWithRootViewController:_conversationListViewController];
        UINavigationController *detail = [[UINavigationController alloc] initWithRootViewController:conversationViewController];
        split.viewControllers = @[master, detail];
        split.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
        
        [_controller presentViewController:split animated:true completion:nil];
    } else {
        _conversationListViewController = [[ConversationListViewController alloc] initWithNibName:nil bundle:nil];
        [_controller pushViewController:_conversationListViewController animated:YES];
    }
}

- (void)logout {
    [[CatalyzeUser currentUser] logout];
    AWSSNS *sns = [AWSSNS defaultSNS];
    AWSSNSDeleteEndpointInput *input = [AWSSNSDeleteEndpointInput new];
    input.endpointArn = [[NSUserDefaults standardUserDefaults] valueForKey:kEndpointArn];
    [[sns deleteEndpoint:input] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            NSLog(@"Error: %@",task.error);
        }
        _signInViewController = [[SignInViewController alloc] initWithNibName:nil bundle:nil];
        _signInViewController.delegate = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [_controller popToRootViewControllerAnimated:YES];
        });
        return nil;
    }];
}

- (void)openedConversation:(NSString *)conversationId {
    NSMutableSet *unread = [NSMutableSet setWithArray:[[NSUserDefaults standardUserDefaults] objectForKey:kConversations]];
    [unread removeObject:conversationId];
    [[NSUserDefaults standardUserDefaults] setObject:[unread allObjects] forKey:kConversations];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [UIApplication sharedApplication].applicationIconBadgeNumber = unread.count;
}

@end
