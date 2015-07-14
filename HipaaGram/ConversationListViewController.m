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

#import "ConversationListViewController.h"
#import "ConversationListTableViewCell.h"
#import "ConversationViewController.h"
#import "ContactsViewController.h"
#import "SignInViewController.h"
#import "AppDelegate.h"
#import "Catalyze.h"
#import "AWSCore.h"
#import "AWSSNS.h"
#import "MBProgressHUD.h"

@interface ConversationListViewController ()

@property BOOL fetchOwn;
@property BOOL fetchAuthor;

@end

@implementation ConversationListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.hidesBackButton = YES;
    NSInteger totalUnread = [(AppDelegate *)[UIApplication sharedApplication].delegate totalUnreadNotifications];
    NSString *modifier = totalUnread > 0 ? [NSString stringWithFormat:@" (%ld)", totalUnread] : @"";
    self.navigationItem.title = [NSString stringWithFormat:@"Conversations%@", modifier];
    
    _fetchOwn = NO;
    _fetchAuthor = YES;
    
    UIBarButtonItem *left = [[UIBarButtonItem alloc] initWithTitle:@"Sign Out" style:UIBarButtonItemStylePlain target:self action:@selector(logout)];
    [left setTitleTextAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"AvenirNext-Medium" size:18.0]} forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem = left;
    
#ifdef LIST_CONTACTS
    UIBarButtonItem *right = [[UIBarButtonItem alloc] initWithTitle:@"+" style:UIBarButtonItemStylePlain target:self action:@selector(addConversation)];
#else
    UIBarButtonItem *right = [[UIBarButtonItem alloc] initWithTitle:@"+" style:UIBarButtonItemStylePlain target:self action:@selector(typeUsername)];
#endif
    [right setTitleTextAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"AvenirNext-Medium" size:28.0]} forState:UIControlStateNormal];
    self.navigationItem.rightBarButtonItem = right;
    
    _conversations = [NSMutableArray array];
    
    [_tblConversationList registerNib:[UINib nibWithNibName:@"ConversationListTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"ConversationListCellIdentifier"];
    [_tblConversationList reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self fetchConversationList];
}

- (void)updateDeviceToken {
    NSString *deviceToken = [[NSUserDefaults standardUserDefaults] valueForKey:kEndpointArn];
    if (_fetchOwn && _fetchAuthor && deviceToken) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            [(AppDelegate *)[UIApplication sharedApplication].delegate updateConversations:_conversations withDeviceToken:[[NSUserDefaults standardUserDefaults] valueForKey:kEndpointArn]];
        });
    }
}

- (void)fetchConversationList {
    _conversations = [NSMutableArray array];
    CatalyzeQuery *query = [CatalyzeQuery queryWithClassName:@"conversations"];
    [query setPageNumber:1];
    [query setPageSize:50];
    [query retrieveInBackgroundWithSuccess:^(NSArray *result) {
        [_conversations addObjectsFromArray:result];
        [_tblConversationList reloadData];
        _fetchOwn = YES;
        [self updateDeviceToken];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        NSLog(@"Could not fetch the list of conversations you own: %@", error.localizedDescription);
    }];
    CatalyzeQuery *queryAuthor = [CatalyzeQuery queryWithClassName:@"conversations"];
    [queryAuthor setPageNumber:1];
    [queryAuthor setPageSize:50];
    [queryAuthor setQueryField:@"authorId"];
    [queryAuthor setQueryValue:[[CatalyzeUser currentUser] usersId]];
    [queryAuthor retrieveInBackgroundWithSuccess:^(NSArray *result) {
        [_conversations addObjectsFromArray:result];
        [_tblConversationList reloadData];
        _fetchAuthor = YES;
        [self updateDeviceToken];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        NSLog(@"Could not fetch the list of conversations you author: %@", error.localizedDescription);
    }];
}

- (void)addConversation {
    ContactsViewController *contactsViewController = [[ContactsViewController alloc] initWithNibName:nil bundle:nil];
    NSMutableSet *currentConversations = [NSMutableSet set];
    for (CatalyzeEntry *entry in _conversations) {
        [currentConversations addObject:[[entry content] valueForKey:@"recipient"]];
        [currentConversations addObject:[[entry content] valueForKey:@"sender"]];
    }
    contactsViewController.currentConversations = [NSMutableArray arrayWithArray:[currentConversations allObjects]];
    [self.navigationController pushViewController:contactsViewController animated:YES];
}

- (void)typeUsername {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:@"Who do you want to chat with today? (type their username)" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    alert.alertViewStyle = UIAlertViewStylePlainTextInput;
    [alert show];
}

- (void)logout {
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] logout];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ConversationListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ConversationListCellIdentifier"];
    CatalyzeEntry *conversation = [_conversations objectAtIndex:indexPath.row];
    BOOL unread = [[[NSDictionary dictionaryWithDictionary:[[NSUserDefaults standardUserDefaults] objectForKey:kConversations]] valueForKey:conversation.entryId] integerValue] > 0;
    if (![[[conversation content] valueForKey:@"recipient_id"] isEqualToString:[[CatalyzeUser currentUser] usersId]]) {
        [cell setCellData:[[conversation content] valueForKey:@"recipient"] unread:unread];
    } else {
        [cell setCellData:[[conversation content] valueForKey:@"sender"] unread:unread];
    }
    [cell setHighlighted:NO animated:NO];
    [cell setSelected:NO animated:NO];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _conversations.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    CatalyzeEntry *conversation = [_conversations objectAtIndex:indexPath.row];
    
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] openedConversation:[conversation entryId]];
    
    ConversationViewController *conversationViewController = [[ConversationViewController alloc] initWithNibName:nil bundle:nil];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        // if we're on an ipad, this VC already exists as the detail view of a split VC
        conversationViewController = (ConversationViewController *)((UINavigationController *)self.splitViewController.viewControllers.lastObject).viewControllers.lastObject;
    }
    
    NSString *prefix;
    if (![[[conversation content] valueForKey:@"recipient_id"] isEqualToString:[[CatalyzeUser currentUser] usersId]]) {
        prefix = @"recipient";
    } else {
        prefix = @"sender";
    }
    conversationViewController.username = [[conversation content] valueForKey:[NSString stringWithFormat:@"%@", prefix]];
    conversationViewController.userId = [[conversation content] valueForKey:[NSString stringWithFormat:@"%@_id", prefix]];
    conversationViewController.deviceToken = [[conversation content] valueForKey:[NSString stringWithFormat:@"%@_deviceToken", prefix]];
    conversationViewController.conversationsId = [conversation entryId];
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [conversationViewController reload];
    } else {
        [self.navigationController pushViewController:conversationViewController animated:YES];
    }
}

#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        [alertView dismissWithClickedButtonIndex:0 animated:YES];
        NSString *username = [alertView textFieldAtIndex:0].text;
        if (username.length > 0) {
            if ([self conversationAlreadyExists:username]) {
                [[[UIAlertView alloc] initWithTitle:@"Oops!" message:[NSString stringWithFormat:@"A conversation with %@ has already been started. Tap on their name to start chatting", username] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
                return;
            }
            [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            CatalyzeQuery *query = [CatalyzeQuery queryWithClassName:@"contacts"];
            query.queryField = kUserUsername;
            query.queryValue = username;
            query.pageNumber = 1;
            query.pageSize = 1;
            [query retrieveAllEntriesInBackgroundWithSuccess:^(NSArray *result) {
                if (result.count == 0) {
                    [MBProgressHUD hideHUDForView:self.view animated:YES];
                    [[[UIAlertView alloc] initWithTitle:@"Uh-oh" message:[NSString stringWithFormat:@"A user with username %@ does not exist. Let's try that again", username] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
                } else {
                    // start the conversation
                    [self startConversation:[result objectAtIndex:0] success:^(id result) {
                        [MBProgressHUD hideHUDForView:self.view animated:YES];
                        [self fetchConversationList];
                    } failure:^(NSDictionary *result, int status, NSError *error) {
                        [MBProgressHUD hideHUDForView:self.view animated:YES];
                        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Could not start conversation: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
                    }];
                }
            } failure:^(NSDictionary *result, int status, NSError *error) {
                [MBProgressHUD hideHUDForView:self.view animated:YES];
                [[[UIAlertView alloc] initWithTitle:@"Error" message:@"Could not check if that user exists, please try again" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
            }];
        }
    }
}

- (BOOL)conversationAlreadyExists:(NSString *)user {
    BOOL exists = NO;
    for (CatalyzeEntry *conversation in _conversations) {
        if ([[[conversation content] valueForKey:@"sender"] isEqualToString:user] || [[[conversation content] valueForKey:@"recipient"] isEqualToString:user]) {
            exists = YES;
            break;
        }
    }
    return exists;
}

@end
