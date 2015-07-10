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

#import "HipaaGramViewController.h"
#import "Catalyze.h"

@interface HipaaGramViewController ()

@end

@implementation HipaaGramViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBarHidden = NO;
    self.navigationController.navigationBar.backItem.title = @"";
    self.navigationItem.hidesBackButton = YES;
}

- (void)back {
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)startConversation:(CatalyzeEntry *)contact success:(CatalyzeSuccessBlock)success failure:(CatalyzeFailureBlock)failure {
    CatalyzeEntry *entry = [CatalyzeEntry entryWithClassName:@"conversations"];
    [[entry content] setValue:[[NSUserDefaults standardUserDefaults] valueForKey:kUserUsername] forKey:@"sender"];
    [[entry content] setValue:[[contact content] valueForKey:kUserUsername] forKey:@"recipient"];
    [[entry content] setValue:[[CatalyzeUser currentUser] usersId] forKey:@"sender_id"];
    [[entry content] setValue:[[contact content] valueForKey:@"user_usersId"] forKey:@"recipient_id"];
    [[entry content] setValue:[[NSUserDefaults standardUserDefaults] valueForKey:kEndpointArn] forKey:@"sender_deviceToken"];
    [[entry content] setValue:[[contact content] valueForKey:kUserDeviceToken] forKey:@"recipient_deviceToken"];
    [entry createInBackgroundForUserWithUsersId:[[contact content] valueForKey:@"user_usersId"] success:success failure:failure];
}

@end
