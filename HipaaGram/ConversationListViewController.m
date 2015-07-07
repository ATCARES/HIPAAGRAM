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

#import "ConversationListViewController.h"
#import "ConversationListTableViewCell.h"
#import "ConversationViewController.h"
#import "ContactsViewController.h"
#import "SignInViewController.h"
#import "AppDelegate.h"
#import "Catalyze.h"
#import "AWSCore.h"
#import "AWSSNS.h"

@interface ConversationListViewController ()

@property (strong, nonatomic) NSMutableArray *conversations;

@end

@implementation ConversationListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.hidesBackButton = YES;
    self.navigationItem.title = @"Conversations";
    
    UIBarButtonItem *logout = [[UIBarButtonItem alloc] initWithTitle:@"\uf08b" style:UIBarButtonItemStylePlain target:self action:@selector(logout)];
    [logout setTitleTextAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"FontAwesome" size:[UIFont buttonFontSize]]} forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem = logout;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addConversation)];
    
    _conversations = [NSMutableArray array];
    
    [_tblConversationList registerNib:[UINib nibWithNibName:@"ConversationListTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"ConversationListCellIdentifier"];
    [_tblConversationList reloadData];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self fetchConversationList];
}

- (void)fetchConversationList {
    _conversations = [NSMutableArray array];
    CatalyzeQuery *query = [CatalyzeQuery queryWithClassName:@"conversations"];
    [query setPageNumber:1];
    [query setPageSize:20];
    [query retrieveInBackgroundWithSuccess:^(NSArray *result) {
        [_conversations addObjectsFromArray:result];
        [_tblConversationList reloadData];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        NSLog(@"Could not fetch the list of conversations you own: %@", error.localizedDescription);
    }];
    CatalyzeQuery *queryAuthor = [CatalyzeQuery queryWithClassName:@"conversations"];
    [queryAuthor setPageNumber:1];
    [queryAuthor setPageSize:20];
    [queryAuthor setQueryField:@"authorId"];
    [queryAuthor setQueryValue:[[CatalyzeUser currentUser] usersId]];
    [queryAuthor retrieveInBackgroundWithSuccess:^(NSArray *result) {
        [_conversations addObjectsFromArray:result];
        [_tblConversationList reloadData];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        NSLog(@"Could not fetch the list of conversations you author: %@", error.localizedDescription);
    }];
}

- (void)addConversation {
    ContactsViewController *contactsViewController = [[ContactsViewController alloc] initWithNibName:nil bundle:nil];
    NSMutableArray *currentConversations = [NSMutableArray array];
    for (CatalyzeEntry *entry in _conversations) {
        [currentConversations addObject:[[entry content] valueForKey:@"recipient"]];
        [currentConversations addObject:[[entry content] valueForKey:@"sender"]];
    }
    contactsViewController.currentConversations = currentConversations;
    [self.navigationController pushViewController:contactsViewController animated:YES];
}

- (void)logout {
    [(AppDelegate *)[[UIApplication sharedApplication] delegate] logout];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ConversationListTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ConversationListCellIdentifier"];
    CatalyzeEntry *conversation = [_conversations objectAtIndex:indexPath.row];
    if (![[[conversation content] valueForKey:@"recipient_id"] isEqualToString:[[CatalyzeUser currentUser] usersId]]) {
        [cell setCellData:[[conversation content] valueForKey:@"recipient"]];
    } else {
        [cell setCellData:[[conversation content] valueForKey:@"sender"]];
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

@end
