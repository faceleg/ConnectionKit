//
//  ABPerson+IMStatus.h
//  IMStatusPagelet
//
//  Created by Mike on 25/05/2007.
//  Copyright 2007 Karelia Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AddressBook/AddressBook.h>


@interface ABPerson (IMStatus)
- (NSString *)firstAIMUsername;
- (NSString *)firstYahooUsername;
@end
