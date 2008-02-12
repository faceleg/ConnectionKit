//
//  KTApplication.h
//  Marvel
//
//  Created by Terrence Talbot on 10/2/04.
//  Copyright 2004 Biophony, LLC. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface KTApplication : NSApplication

+(NSString * )machineName;
- (void)showHelpPage:(NSString *)inHelpString;

@end