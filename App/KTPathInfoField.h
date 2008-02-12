/* KTPathInfoField */

#import <Cocoa/Cocoa.h>

@interface KTPathInfoField : NSTextField
{
}

- (NSArray *)supportedDragTypes;

@end


@interface NSObject (KTPathInfoFieldDelegate)
- (NSArray *)supportedDragTypesForPathInfoField:(KTPathInfoField *)pathInfoField;

- (NSDragOperation)pathInfoField:(KTPathInfoField *)field
				validateFileDrop:(NSString *)path operationMask:(NSDragOperation)dragMask;

- (BOOL)pathInfoField:(KTPathInfoField *)field
 performDragOperation:(id <NSDraggingInfo>)sender
	 expectedDropType:(NSDragOperation)dragOp;
	 
@end