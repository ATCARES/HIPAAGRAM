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

#import <UIKit/UIKit.h>
#import "SignInViewController.h"
#import "ConversationListViewController.h"
#import "ConversationViewController.h"

@interface AppDelegate : UIResponder <UIApplicationDelegate, SignInDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) id<PushNotificationHandler> handler;

- (void)logout;
- (void)openedConversation:(NSString *)conversationId;
- (void)updateConversations:(NSArray *)conversations withDeviceToken:(NSString *)deviceToken;
- (NSInteger)totalUnreadNotifications;
- (NSInteger)totalUnreadNotifications:(NSDictionary *)unread;

@end
