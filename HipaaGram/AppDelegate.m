/*
 * Copyright (C) 2015 Catalyze, Inc.
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
        [[NSUserDefaults standardUserDefaults] setObject:[NSDictionary dictionary] forKey:kConversations];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    UIColor *green = [UIColor colorWithRed:GREEN_r green:GREEN_g blue:GREEN_b alpha:1.0f];
    [[UINavigationBar appearance] setTintColor:green];
    [[UINavigationBar appearance] setTitleTextAttributes:@{NSForegroundColorAttributeName: green, NSFontAttributeName: [UIFont fontWithName:@"AvenirNext-Bold" size:18.0]}];
    
    _signInViewController = [[SignInViewController alloc] initWithNibName:nil bundle:nil];
    _signInViewController.delegate = self;
    _controller = [[UINavigationController alloc] initWithRootViewController:_signInViewController];
    self.window.rootViewController = _controller;
    
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    [Catalyze setApiKey:API_KEY applicationId:APP_ID];
    [Catalyze setLoggingLevel:kLoggingLevelDebug];
    
    UILocalNotification *note = [launchOptions objectForKey:UIApplicationLaunchOptionsRemoteNotificationKey];
    if (note) {
        // we opened the app by tapping on a notification
        // TODO open that conversation
    }
    
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
    
    AWSCognitoCredentialsProvider *credentialsProvider = [[AWSCognitoCredentialsProvider alloc] initWithRegionType:AWSRegionUSEast1 identityPoolId:IDENTITY_POOL_ID];
    
    AWSServiceConfiguration *configuration = [[AWSServiceConfiguration alloc] initWithRegion:AWSRegionUSEast1
                                                                         credentialsProvider:credentialsProvider];
    
    [AWSServiceManager defaultServiceManager].defaultServiceConfiguration = configuration;
    
    AWSSNS *sns = [AWSSNS defaultSNS];
    AWSSNSCreatePlatformEndpointInput *request = [AWSSNSCreatePlatformEndpointInput new];
    request.token = deviceTokenString;
    request.attributes = @{@"Enabled": @"true"};
    request.platformApplicationArn = APPLICATION_ARN;
    [[sns createPlatformEndpoint:request] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            NSLog(@"Error: %@",task.error);
        } else {
            AWSSNSCreateEndpointResponse *createEndPointResponse = task.result;
            [[NSUserDefaults standardUserDefaults] setObject:createEndPointResponse.endpointArn forKey:kEndpointArn];
            [[NSUserDefaults standardUserDefaults] synchronize];
            [_conversationListViewController updateDeviceToken];
        }
        return nil;
    }];
}

- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    NSLog(@"failed to register for push notifications %@", error.localizedDescription);
}

- (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    NSMutableDictionary *unread = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:kConversations]];
    NSString *conversationId = [userInfo valueForKey:kConversationId];
    // if this conversation is active, tell the handler. otherwise add it to the unread count
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive && _handler && [[_handler handlerFor] isEqualToString:conversationId]) {
        [_handler handleNotification:conversationId];
    } else {
        NSInteger conversationUnread = [[unread objectForKey:conversationId] integerValue];
        [unread setValue:@(++conversationUnread) forKey:conversationId];
        [[NSUserDefaults standardUserDefaults] setObject:unread forKey:kConversations];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    
    NSInteger totalUnread = [self totalUnreadNotifications:unread];
    
    application.applicationIconBadgeNumber = totalUnread;
    [_conversationListViewController.tblConversationList reloadData];
    NSString *modifier = totalUnread > 0 ? [NSString stringWithFormat:@" (%ld)", totalUnread] : @"";
    _conversationListViewController.title = [NSString stringWithFormat:@"Conversations%@", modifier];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationReceived object:nil userInfo:@{@"unread": @(totalUnread)}];
}

#pragma mark - SignInDelegate

- (void)signInSuccessful {
    // this is called on a background thread, so updating the UI has to be done on the main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [_signInViewController.view endEditing:YES];
        _signInViewController.txtPhoneNumber.text = @"";
        _signInViewController.txtPassword.text = @"";
    });
    
    _conversationListViewController = [[ConversationListViewController alloc] initWithNibName:nil bundle:nil];
    // if we're on an iPad, use a split VC
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        UISplitViewController *split = [[UISplitViewController alloc] init];
        
        ConversationViewController *conversationViewController = [[ConversationViewController alloc] initWithNibName:nil bundle:nil];
        
        UINavigationController *master = [[UINavigationController alloc] initWithRootViewController:_conversationListViewController];
        UINavigationController *detail = [[UINavigationController alloc] initWithRootViewController:conversationViewController];
        split.viewControllers = @[master, detail];
        split.preferredDisplayMode = UISplitViewControllerDisplayModeAllVisible;
        
        [_controller presentViewController:split animated:true completion:nil];
    } else {
        [_controller pushViewController:_conversationListViewController animated:YES];
    }
    
    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound;
    UIUserNotificationSettings *settings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    [[UIApplication sharedApplication] registerUserNotificationSettings:settings];
    [[UIApplication sharedApplication] registerForRemoteNotifications];
}

- (void)logout {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserUsername];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kUserEmail];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:kConversations];
    [[NSUserDefaults standardUserDefaults] synchronize];
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
    [[CatalyzeUser currentUser] logout];
    [[UIApplication sharedApplication] unregisterForRemoteNotifications];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [[_controller presentedViewController] dismissViewControllerAnimated:YES completion:nil];
    } else {
        [_controller popToRootViewControllerAnimated:YES];
    }
}

- (void)openedConversation:(NSString *)conversationId {
    NSMutableDictionary *unread = [NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:kConversations]];
    [unread removeObjectForKey:conversationId];
    [[NSUserDefaults standardUserDefaults] setObject:unread forKey:kConversations];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    NSInteger totalUnread = [self totalUnreadNotifications:unread];
    
    [UIApplication sharedApplication].applicationIconBadgeNumber = totalUnread;
    [_conversationListViewController.tblConversationList reloadData];
    NSString *modifier = totalUnread > 0 ? [NSString stringWithFormat:@" (%ld)", totalUnread] : @"";
    _conversationListViewController.title = [NSString stringWithFormat:@"Conversations%@", modifier];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationReceived object:nil userInfo:@{@"unread": @(totalUnread)}];
}

- (void)updateConversations:(NSArray *)conversations withDeviceToken:(NSString *)deviceToken {
    for (CatalyzeEntry *conversation in conversations) {
        if ([[[conversation content] valueForKey:@"sender_id"] isEqualToString:[[CatalyzeUser currentUser] usersId]]) {
            [[conversation content] setObject:deviceToken forKey:@"sender_deviceToken"];
        } else {
            [[conversation content] setObject:deviceToken forKey:@"recipient_deviceToken"];
        }
        [conversation saveInBackground];
    }
    CatalyzeQuery *query = [CatalyzeQuery queryWithClassName:@"contacts"];
    query.queryField = kUserUsername;
    query.queryValue = [[CatalyzeUser currentUser] username];
    query.pageNumber = 1;
    query.pageSize = 1;
    [query retrieveInBackgroundWithSuccess:^(NSArray *result) {
        CatalyzeEntry *contact = [result objectAtIndex:0];
        [[contact content] setObject:deviceToken forKey:kUserDeviceToken];
        [contact saveInBackground];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        NSLog(@"failed to update our contact with the latest device token: %@ %@", result, error);
    }];
}

- (NSInteger)totalUnreadNotifications {
    return [self totalUnreadNotifications:[NSMutableDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:kConversations]]];
}

- (NSInteger)totalUnreadNotifications:(NSDictionary *)unread {
    NSInteger totalUnread = 0;
    for (NSString *key in [unread allKeys]) {
        totalUnread += [[unread valueForKey:key] integerValue];
    }
    return totalUnread;
}

@end
