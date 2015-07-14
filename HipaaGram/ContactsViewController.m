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

#import "ContactsViewController.h"
#import "ContactTableViewCell.h"
#import "AFNetworking.h"
#import "Catalyze.h"
#import "MBProgressHUD.h"

@interface ContactsViewController ()

@property (strong, nonatomic) NSMutableArray *contacts;

@end

@implementation ContactsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.navigationItem.title = @"Contacts";
    
    UIBarButtonItem *left = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(back)];
    [left setTitleTextAttributes:@{NSFontAttributeName: [UIFont fontWithName:@"AvenirNext-Medium" size:18.0]} forState:UIControlStateNormal];
    self.navigationItem.leftBarButtonItem = left;
    
    _contacts = [NSMutableArray array];
    [_tblContacts registerNib:[UINib nibWithNibName:@"ContactTableViewCell" bundle:[NSBundle mainBundle]] forCellReuseIdentifier:@"ContactCellIdentifier"];
    [_tblContacts reloadData];
    
    [self fetchContacts];
}

- (void)fetchContacts {
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    CatalyzeQuery *query = [CatalyzeQuery queryWithClassName:@"contacts"];
    [query setPageNumber:1];
    [query setPageSize:100];
    [query retrieveAllEntriesInBackgroundWithSuccess:^(NSArray *result) {
        for (CatalyzeEntry *entry in result) {
            if (![[[entry content] valueForKey:@"user_username"] isEqualToString:[[NSUserDefaults standardUserDefaults] valueForKey:kUserUsername]] && ![_currentConversations containsObject:[[entry content] valueForKey:@"user_username"]]) {
                [_contacts addObject:entry];
                [_currentConversations addObject:[[entry content] valueForKey:@"user_username"]];
            }
        }
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [_tblContacts reloadData];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Could not fetch the contacts: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

#pragma mark - UITableViewDataSource

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    ContactTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ContactCellIdentifier"];
    [cell setSelected:NO animated:NO];
    [cell setHighlighted:NO animated:NO];
    [cell setCellData:[[[_contacts objectAtIndex:indexPath.row] content] valueForKey:@"user_username"]];
    return cell;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _contacts.count;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 44.0f;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [[tableView cellForRowAtIndexPath:indexPath] setSelected:NO animated:YES];
    [[tableView cellForRowAtIndexPath:indexPath] setHighlighted:NO animated:YES];
    [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [self startConversation:[_contacts objectAtIndex:indexPath.row] success:^(id result) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [self.navigationController popViewControllerAnimated:YES];
    } failure:^(NSDictionary *result, int status, NSError *error) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        [[[UIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Could not start conversation: %@", error.localizedDescription] delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil] show];
    }];
}

@end
