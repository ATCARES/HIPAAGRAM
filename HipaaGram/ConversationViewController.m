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

#import "ConversationViewController.h"
#import "Message.h"
#import "AppDelegate.h"
#import "MessageTableViewCell.h"
#import "AWSCore.h"
#import "AWSSNS.h"

@interface ConversationViewController ()

@property (weak, nonatomic) IBOutlet UITableView *tblMessages;
@property (strong, nonatomic) NSMutableArray *messages;
@property (weak, nonatomic) IBOutlet UIButton *btnSend;
@property (weak, nonatomic) IBOutlet UITextField *txtMessage;
@property (weak, nonatomic) IBOutlet UIView *messageView;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomTableConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *topTableConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

@end

@implementation ConversationViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        NSInteger totalUnread = [(AppDelegate *)[UIApplication sharedApplication].delegate totalUnreadNotifications];
        NSString *modifier = totalUnread > 0 ? [NSString stringWithFormat:@" (%ld)", totalUnread] : @"";
        UIBarButtonItem *left = [[UIBarButtonItem alloc] initWithTitle:[NSString stringWithFormat:@"Back%@", modifier] style:UIBarButtonItemStylePlain target:self action:@selector(back)];
        [left setTitleTextAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"AvenirNext-Medium" size:18.0]} forState:UIControlStateNormal];
        self.navigationItem.leftBarButtonItem = left;
    }
    
    _messageView.layer.borderWidth = 1;
    _messageView.layer.borderColor = [UIColor colorWithRed:221.0/255.0 green:221.0/255.0 blue:221.0/255.0 alpha:1.0].CGColor;
    
    _txtMessage.layer.borderWidth = 1;
    _txtMessage.layer.borderColor = [UIColor colorWithRed:GREEN_r green:GREEN_g blue:GREEN_b alpha:1.0].CGColor;
    _txtMessage.layer.cornerRadius = 5;
    _txtMessage.layer.sublayerTransform = CATransform3DMakeTranslation(10, 0, 0);
    
    if (self.navigationController.navigationBar.isTranslucent) {
        _topTableConstraint.constant = 64.0;
        _bottomTableConstraint.constant = -64.0;
    }
    
    _btnSend.layer.cornerRadius = 5;
    _btnSend.enabled = NO;
    
    _messages = [NSMutableArray array];
    
    [_txtMessage addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    [_tblMessages addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(hideKeyboard)]];
    _tblMessages.estimatedRowHeight = 97;
    _tblMessages.rowHeight = UITableViewAutomaticDimension;
    [_tblMessages registerNib:[UINib nibWithNibName:@"MessageTableViewCell" bundle:nil] forCellReuseIdentifier:@"MessageCellIdentifier"];
    _tblMessages.transform = CGAffineTransformMakeRotation(-M_PI);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(badgeBackButton:) name:kNotificationReceived object:nil];
    [self scrollToBottomAnimated:NO];
    [((AppDelegate *)[UIApplication sharedApplication].delegate) setHandler:self];
    
    [self reload];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [((AppDelegate *)[UIApplication sharedApplication].delegate) setHandler:nil];
}

- (void)badgeBackButton:(NSNotification *)note {
    NSInteger unread = [[note.userInfo objectForKey:@"unread"] integerValue];
    NSString *modifier = unread > 0 ? [NSString stringWithFormat:@" (%ld)", unread] : @"";
    self.navigationItem.leftBarButtonItem.title = [NSString stringWithFormat:@"Back%@", modifier];
}

- (void)reload {
    self.title = _username;
    [self queryMessages];
}

- (void)hideKeyboard {
    [_txtMessage resignFirstResponder];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    _bottomConstraint.constant = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size.height;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    _bottomConstraint.constant = 0;
}

- (IBAction)sendMessage:(id)sender {
    if ([_txtMessage.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]].length == 0) {
        return;
    }
    Message *msg = [[Message alloc] initWithClassName:@"messages"];
    [[msg content] setValue:_txtMessage.text forKey:@"msgContent"];
    [[msg content] setValue:_username forKey:@"toPhone"];
    [[msg content] setValue:[[NSUserDefaults standardUserDefaults] valueForKey:kUserUsername] forKey:@"fromPhone"];
    
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"MM-dd-yyyy HH:mm:ss.SSSSSS"];
    
    [[msg content] setValue:[format stringFromDate:[NSDate date]] forKey:@"timestamp"];
    [[msg content] setValue:_txtMessage.text forKey:@"msgContent"];
    [[msg content] setValue:[NSNumber numberWithBool:NO] forKey:@"isPhi"];
    [[msg content] setValue:@"" forKey:@"fileId"];
    [[msg content] setValue:_conversationsId forKey:@"conversationsId"];
    [msg createInBackgroundWithSuccess:^(id result) {
        // woohoo
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Could not send the message: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
    [_tblMessages beginUpdates];
    [_messages insertObject:msg atIndex:0];
    [_tblMessages insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationLeft];
    _txtMessage.text = @"";
    _btnSend.enabled = NO;
    [_tblMessages endUpdates];
    [self scrollToBottomAnimated:YES];
    
    [msg createInBackgroundForUserWithUsersId:_userId success:^(id result) {
        [self sendNotification];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Could not send the message: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

- (void)scrollToBottomAnimated:(BOOL)animated {
    if (_messages.count > 0) {
        [_tblMessages scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
    }
}

- (void)queryMessages {
    CatalyzeQuery *query = [CatalyzeQuery queryWithClassName:@"messages"];
    query.queryField = @"conversationsId";
    query.queryValue = _conversationsId;
    query.pageNumber = 1;
    query.pageSize = 200;
    // bit of a hack. since the iOS SDK doesn't support the direction flag, tack it onto our usersId since thats the last part of the path and we have no other query params
    [query retrieveInBackgroundForUsersId:[NSString stringWithFormat:@"%@?direction=desc", [[CatalyzeUser currentUser] usersId]] success:^(NSArray *result) {
        [_messages removeAllObjects];
        for (CatalyzeEntry *entry in result) {
            // can't query by conversationsId and parentId, so we have to filter once we get the results back
            if ([[entry parentId] isEqualToString:[[CatalyzeUser currentUser] usersId]]) {
                [_messages addObject:[[Message alloc] initWithClassName:@"messages" dictionary:[entry content]]];
            }
        }
        [_messages sortUsingComparator:^NSComparisonResult(Message *msg1, Message *msg2) {
            return [[[msg2 content] valueForKey:@"timestamp"] compare:[[msg1 content] valueForKey:@"timestamp"]];
        }];
        [_tblMessages reloadData];
        [self scrollToBottomAnimated:YES];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Could not fetch previous messages" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

- (void)sendNotification {
    AWSSNS *sns = [AWSSNS defaultSNS];
    AWSSNSPublishInput *input = [AWSSNSPublishInput new];
    // SNS forces you to escape nested json rather than just keeping it as json...
    // please note that you are no longer HIPAA compliant if you send any PHI in this notification. Keep it generic such as 'You've got a new message!' which then triggers a refresh in the UI
    NSString *payload = [NSString stringWithFormat:@"{\\\"aps\\\": {\\\"alert\\\": \\\"You've got a new message!\\\", \\\"badge\\\": \\\"+1\\\", \\\"content-available\\\": 1, \\\"sound\\\": \\\"default\\\"}, \\\"%@\\\": \\\"%@\\\"}", kConversationId, _conversationsId];
    input.message = [NSString stringWithFormat:@"{\"%@\": \"%@\"}", ENDPOINT_NAME, payload];
    input.messageStructure = @"json";
    input.targetArn = _deviceToken;
    
    [[sns publish:input] continueWithBlock:^id(AWSTask *task) {
        if (task.error) {
            NSLog(@"Push Notification Error: %@",task.error);
        }
        return nil;
    }];
}

#pragma mark - UITextFieldDelegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)textFieldDidChange:(UITextField *)textField {
    _btnSend.enabled = _txtMessage.text.length > 0;
}

#pragma mark - PushNotificationHandler

- (NSString *)handlerFor {
    return _conversationsId;
}

- (void)handleNotification:(NSString *)fromNumber {
    NSLog(@"I got a msg, querying for it...");
    [self queryMessages];
}

#pragma mark - UITableViewDataSource
#pragma mark - UITableViewDelegate

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MessageTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MessageCellIdentifier"];
    Message *message = [_messages objectAtIndex:indexPath.row];
    BOOL sender = [[[message content] valueForKey:@"fromPhone"] isEqualToString:[[NSUserDefaults standardUserDefaults] valueForKey:kUserUsername]];
    [cell initializeWithMessage:message sender:sender];
    cell.contentView.transform = CGAffineTransformMakeRotation(M_PI);
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _messages.count;
}

@end
