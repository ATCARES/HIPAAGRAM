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

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationController.navigationBarHidden = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)enableRegistration {
    _btnRegister.alpha = 1.0f;
    _btnRegister.userInteractionEnabled = YES;
    
    [_btnSignIn setTitleColor:_btnSignIn.backgroundColor forState:UIControlStateNormal];
    _btnSignIn.backgroundColor = [UIColor whiteColor];
    
    [UIView animateWithDuration:0.3 animations:^{
        _txtPhoneNumber.alpha = 1.0f;
        _txtPhoneNumber.userInteractionEnabled = YES;
        
        CGRect frame = _btnSignIn.frame;
        frame.origin.y = _btnRegister.frame.origin.y + _btnRegister.frame.size.height + 8;
        [_btnSignIn setFrame:frame];
    }];
}

- (void)disableRegistration {
    [UIView animateWithDuration:0.3 animations:^{
        _txtPhoneNumber.alpha = 0.0f;
        _txtPhoneNumber.userInteractionEnabled = NO;
        
        CGRect frame = _btnSignIn.frame;
        frame.origin.y = _btnRegister.frame.origin.y;
        [_btnSignIn setFrame:frame];
    } completion:^(BOOL finished) {
        _btnRegister.alpha = 0.0f;
        _btnRegister.userInteractionEnabled = NO;
        
        _btnSignIn.backgroundColor = [_btnSignIn titleColorForState:UIControlStateNormal];
        [_btnSignIn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    }];
}

- (IBAction)signIn:(id)sender {
    if (_btnRegister.alpha == 1.0f) {
        [self disableRegistration];
    } else if ([[NSUserDefaults standardUserDefaults] valueForKey:kUserUsername]) {
        [CatalyzeUser logInWithUsernameInBackground:[[NSUserDefaults standardUserDefaults] valueForKey:kUserUsername] password:_txtPassword.text success:^(CatalyzeUser *result) {
            if (![[NSUserDefaults standardUserDefaults] boolForKey:@"added_to_contacts"]) {
                [self addToContacts:[[CatalyzeUser currentUser] username] usersId:[[CatalyzeUser currentUser] usersId]];
            }
            [_delegate signInSuccessful];
        } failure:^(NSDictionary *result, int status, NSError *error) {
            if (status == 404) {
                [self enableRegistration];
            } else {
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Invalid username / password" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
            }
        }];
    } else {
        [self enableRegistration];
    }
}

- (IBAction)registerUser:(id)sender {
    if (_txtPhoneNumber.text.length == 0 || _txtPassword.text.length == 0) {
        return;
    }
    
    Email *email = [[Email alloc] init];
    email.primary = [self randomEmail];
    
    [CatalyzeUser signUpWithUsernameInBackground:_txtPhoneNumber.text email:email name:[[Name alloc] init] password:_txtPassword.text success:^(CatalyzeUser *result) {
        [[NSUserDefaults standardUserDefaults] setValue:[result usersId] forKey:@"usersId"];
        [[NSUserDefaults standardUserDefaults] setValue:email.primary forKey:kUserEmail];
        [[NSUserDefaults standardUserDefaults] setValue:_txtPhoneNumber.text forKey:kUserUsername];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
        [[[UIAlertView alloc] initWithTitle:@"Success" message:@"Please activate your account and then sign in" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        [self disableRegistration];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Could not sign up: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

- (void)addToContacts:(NSString *)username usersId:(NSString *)usersId {
    CatalyzeEntry *contact = [CatalyzeEntry entryWithClassName:@"contacts"];
    [[contact content] setValue:username forKey:@"user_username"];
    [[contact content] setValue:usersId forKey:@"user_usersId"];
    [contact createInBackgroundWithSuccess:^(id result) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"added_to_contacts"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        NSLog(@"Was not added to the contacts custom class!");
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
