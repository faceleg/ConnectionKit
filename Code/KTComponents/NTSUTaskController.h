//  ====================================================================== 	//
//  NTSUTaskController.h														//
//  ====================================================================== 	//

#import <Cocoa/Cocoa.h>
#import <Security/Authorization.h>

@interface NTSUTaskController : NSObject
{
    AuthorizationRef authorizationRef;
}

+ (id)sharedInstance;

- (BOOL)executeCommand:(BOOL)asynchronous pathToCommand:(NSString *)pathToCommand withArgs:(NSArray *)arguments delegate:(id)delegate;

@end

@interface NSObject ( NTSUTaskControllerDelegate )
					  
- (void)delegate_handleTaskOutput:(NSString *)output;

@end