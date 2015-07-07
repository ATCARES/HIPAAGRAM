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

#import "SignInViewController.h"
#import "Catalyze.h"

@interface SignInViewController ()

@end

@implementation SignInViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationController.navigationBarHidden = YES;
}

- (IBAction)signIn:(id)sender {
    if (_txtPhoneNumber.text.length == 0 || _txtPassword.text.length == 0) {
        return;
    }
    [CatalyzeUser logInWithUsernameInBackground:_txtPhoneNumber.text password:_txtPassword.text success:^(CatalyzeUser *result) {
        [[NSUserDefaults standardUserDefaults] setValue:result.usersId forKey:@"usersId"];
        [[NSUserDefaults standardUserDefaults] setValue:result.email.primary forKey:kUserEmail];
        [[NSUserDefaults standardUserDefaults] setValue:_txtPhoneNumber.text forKey:kUserUsername];
        [[NSUserDefaults standardUserDefaults] synchronize];
        if (![[NSUserDefaults standardUserDefaults] boolForKey:@"added_to_contacts"]) {
            [self addToContacts:[[CatalyzeUser currentUser] username] usersId:[[CatalyzeUser currentUser] usersId]];
        } else {
            [_delegate signInSuccessful];
        }
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Invalid username / password" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

- (IBAction)registerUser:(id)sender {
    if (_txtPhoneNumber.text.length == 0 || _txtPassword.text.length == 0) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Please input a valid phone number and password" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        return;
    }
    
    Email *email = [[Email alloc] init];
    email.primary = [self randomEmail];
    
    [CatalyzeUser signUpWithUsernameInBackground:_txtPhoneNumber.text email:email name:[[Name alloc] init] password:_txtPassword.text success:^(CatalyzeUser *result) {
        [[[UIAlertView alloc] initWithTitle:@"Success" message:@"Please activate your account and then sign in" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Could not sign up: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

- (void)addToContacts:(NSString *)username usersId:(NSString *)usersId {
    CatalyzeEntry *contact = [CatalyzeEntry entryWithClassName:@"contacts"];
    [[contact content] setValue:username forKey:@"user_username"];
    [[contact content] setValue:usersId forKey:@"user_usersId"];
    [[contact content] setValue:[[NSUserDefaults standardUserDefaults] valueForKey:kEndpointArn] forKey:@"user_deviceToken"];
    [contact createInBackgroundWithSuccess:^(id result) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"added_to_contacts"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [_delegate signInSuccessful];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        NSLog(@"Was not added to the contacts custom class! This will get resolved upon next sign in.");
        [_delegate signInSuccessful];
    }];
}

// from http://stackoverflow.com/questions/2633801/generate-a-random-alphanumeric-string-in-cocoa
- (NSString *)randomEmail {
    NSString *letters = @"abcdefghijklmnopqrstuvwxyz0123456789";
    NSMutableString *randomString = [NSMutableString stringWithCapacity:10];
    
    for (int i=0; i<10; i++) {
        [randomString appendFormat: @"%C", [letters characterAtIndex: arc4random() % [letters length]]];
    }
    
    return [NSString stringWithFormat:@"josh+%@@catalyze.io", randomString];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

@end
