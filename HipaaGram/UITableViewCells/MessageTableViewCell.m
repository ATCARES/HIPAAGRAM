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

#import "MessageTableViewCell.h"
#import <QuartzCore/QuartzCore.h>

@interface MessageTableViewCell ()

@property (weak, nonatomic) IBOutlet UILabel *lblTimestamp;
@property (weak, nonatomic) IBOutlet UITextView *txtMessage;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *leftConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *rightConstraint;

@end

@implementation MessageTableViewCell

- (void)awakeFromNib {
    _txtMessage.layer.cornerRadius = 5;
    _txtMessage.textContainerInset = UIEdgeInsetsMake(10, 10, 10, 10);
}

- (void)initializeWithMessage:(Message *)message sender:(BOOL)sender {
    _txtMessage.text = [message text];
    
    NSDate *timestamp = [message date];
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    [format setDateFormat:@"MMM dd, yyyy, h:mm a"];
    _lblTimestamp.text = [format stringFromDate:timestamp];
    
    CGFloat usableWidth = [UIScreen mainScreen].bounds.size.width - 16.0f; // 8 for each side padding
    CGFloat idealWidth = usableWidth * 0.8; // ideally we want 80% of the screen width for aesthetics
    // sizeThatFits: doesn't work with UITextViews at all
    CGFloat bigMargin = usableWidth - idealWidth;//idealSize.width;
    CGFloat padding = 0.0; // the auto layout alignment uses an offset from the default
    UIColor *green = [UIColor colorWithRed:GREEN_r green:GREEN_g blue:GREEN_b alpha:1.0f];
    _txtMessage.layer.borderColor = green.CGColor;
    _txtMessage.layer.borderWidth = 1;
    if (sender) {
        _txtMessage.textAlignment = NSTextAlignmentRight;
        _txtMessage.textColor = [UIColor whiteColor];
        _txtMessage.backgroundColor = green;
        _leftConstraint.constant = bigMargin;
        _rightConstraint.constant = padding;
    } else {
        _txtMessage.textAlignment = NSTextAlignmentLeft;
        _txtMessage.textColor = green;
        _txtMessage.backgroundColor = [UIColor whiteColor];
        _leftConstraint.constant = padding;
        _rightConstraint.constant = -1*bigMargin;
    }
    [_txtMessage sizeToFit];
    [self layoutIfNeeded];
}

@end
