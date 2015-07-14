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

#import "SignInViewController.h"
#import "Catalyze.h"
#import "NSString+Validation.h"
#import "MBProgressHUD.h"

@interface SignInViewController ()

@property CAGradientLayer *signInGradient;
@property CAGradientLayer *registerGradient;

@end

@implementation SignInViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.translatesAutoresizingMaskIntoConstraints = YES;
    
    UIColor *green = [UIColor colorWithRed:GREEN_r green:GREEN_g blue:GREEN_b alpha:1.0];
    UIColor *topGreen = [UIColor colorWithRed:122.0/255.0 green:242.0/255.0 blue:190.0/255.0 alpha:1.0];
    UIColor *bottomGreen = [UIColor colorWithRed:42.0/255.0 green:192.0/255.0 blue:127.0/255.0 alpha:1.0];
    UIColor *topBlue = [UIColor colorWithRed:122.0/255.0 green:255.0/255.0 blue:242.0/255.0 alpha:1.0];
    UIColor *bottomBlue = [UIColor colorWithRed:42.0/255.0 green:141.0/255.0 blue:193.0/255.0 alpha:1.0];
    
    _txtPhoneNumber.layer.borderWidth = 1;
    _txtPhoneNumber.layer.borderColor = green.CGColor;
    _txtPhoneNumber.layer.cornerRadius = 5;
    _txtPhoneNumber.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_txtPhoneNumber.placeholder attributes:@{NSForegroundColorAttributeName: green}];
    _txtPhoneNumber.layer.sublayerTransform = CATransform3DMakeTranslation(10, 0, 0);
    
    _txtPassword.layer.borderWidth = 1;
    _txtPassword.layer.borderColor = green.CGColor;
    _txtPassword.layer.cornerRadius = 5;
    _txtPassword.attributedPlaceholder = [[NSAttributedString alloc] initWithString:_txtPassword.placeholder attributes:@{NSForegroundColorAttributeName: green}];
    _txtPassword.layer.sublayerTransform = CATransform3DMakeTranslation(10, 0, 0);
    
    _btnSignIn.layer.cornerRadius = 5;
    _btnSignIn.layer.masksToBounds = YES;
    _btnSignIn.backgroundColor = bottomGreen;
    _btnRegister.layer.cornerRadius = 5;
    _btnRegister.layer.masksToBounds = YES;
    _btnRegister.backgroundColor = bottomBlue;
    
    _signInGradient = [CAGradientLayer layer];
    _signInGradient.colors = @[(id)topGreen.CGColor, (id)bottomGreen.CGColor];
    _signInGradient.frame = _btnSignIn.bounds;
    _signInGradient.cornerRadius = 5;
    
    _registerGradient = [CAGradientLayer layer];
    _registerGradient.colors = @[(id)topBlue.CGColor, (id)bottomBlue.CGColor];
    _registerGradient.frame = _btnRegister.bounds;
    _registerGradient.cornerRadius = 5;
    
    // gradient button filling is only broken on ipad
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [_btnSignIn.layer insertSublayer:_signInGradient atIndex:0];
        [_btnRegister.layer insertSublayer:_registerGradient atIndex:0];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBarHidden = YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // gradient button filling is only broken on ipad
        _signInGradient.frame = _btnSignIn.bounds;
        _registerGradient.frame = _btnRegister.bounds;
        
        [_btnSignIn.layer insertSublayer:_signInGradient atIndex:0];
        [_btnRegister.layer insertSublayer:_registerGradient atIndex:0];
    }
}

- (IBAction)signIn:(id)sender {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self.view endEditing:YES];
    if (_txtPhoneNumber.text.length == 0 || _txtPassword.text.length == 0) {
        return;
    }
    [CatalyzeUser logInWithUsernameInBackground:_txtPhoneNumber.text password:_txtPassword.text success:^(CatalyzeUser *result) {
        [[NSUserDefaults standardUserDefaults] setValue:result.usersId forKey:@"usersId"];
        [[NSUserDefaults standardUserDefaults] setValue:result.email.primary forKey:kUserEmail];
        [[NSUserDefaults standardUserDefaults] setValue:_txtPhoneNumber.text forKey:kUserUsername];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [self addToContacts:[[CatalyzeUser currentUser] username] usersId:[[CatalyzeUser currentUser] usersId]];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Invalid username / password" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

- (IBAction)registerUser:(id)sender {
    [self.view endEditing:YES];
    if (_txtPhoneNumber.text.length == 0 || _txtPassword.text.length == 0) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Please input a valid phone number and password" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        return;
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Registration" message:@"We need your email address in order to send an activation email for your HIPAAGRAM account" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Send", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert textFieldAtIndex:0].keyboardType = UIKeyboardTypeEmailAddress;
    [alert show];
}

- (void)finishRegistration:(NSString *)emailString {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    Email *email = [[Email alloc] init];
    email.primary = emailString;
    
    [CatalyzeUser signUpWithUsernameInBackground:_txtPhoneNumber.text email:email name:[[Name alloc] init] password:_txtPassword.text success:^(CatalyzeUser *result) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [[[UIAlertView alloc] initWithTitle:@"Success" message:@"Please activate your account and then sign in" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Could not sign up: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

- (void)addToContacts:(NSString *)username usersId:(NSString *)usersId {
    CatalyzeQuery *query = [CatalyzeQuery queryWithClassName:@"contacts"];
    query.queryField = kUserUsername;
    query.queryValue = [[CatalyzeUser currentUser] username];
    query.pageNumber = 1;
    query.pageSize = 1;
    [query retrieveInBackgroundWithSuccess:^(NSArray *result) {
        if (result.count == 0) {
            CatalyzeEntry *contact = [CatalyzeEntry entryWithClassName:@"contacts"];
            [[contact content] setValue:username forKey:kUserUsername];
            [[contact content] setValue:usersId forKey:@"user_usersId"];
            [[contact content] setValue:[[NSUserDefaults standardUserDefaults] valueForKey:kEndpointArn] forKey:kUserDeviceToken];
            [contact createInBackgroundWithSuccess:^(id result) {
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                [_delegate signInSuccessful];
            } failure:^(NSDictionary *result, int status, NSError *error) {
                NSLog(@"Was not added to the contacts custom class! This will get resolved upon next sign in. %@ %@", result, error);
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                [_delegate signInSuccessful];
            }];
        } else {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            [_delegate signInSuccessful];
        }
    } failure:^(NSDictionary *result, int status, NSError *error) {
        NSLog(@"Could not determine if we are in the Contacts list, will resolve upon next sign in. %@ %@", result, error);
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [_delegate signInSuccessful];
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    if (textField == _txtPhoneNumber) {
        [_txtPassword becomeFirstResponder];
    }
    return YES;
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(nonnull UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [alertView dismissWithClickedButtonIndex:0 animated:YES];
        NSString *email = [alertView textFieldAtIndex:0].text;
        if ([email isValidEmail]) {
            [self finishRegistration:email];
        } else {
            [[[UIAlertView alloc] initWithTitle:@"Oops!" message:@"It looks like that email wasn't formatted correctly, let's try that again" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
        }
    }
}

@end
