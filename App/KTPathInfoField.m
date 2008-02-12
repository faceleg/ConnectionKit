#import "KTPathInfoField.h"

#import "KTPathInfoFieldCell.h"


@interface KTPathInfoField (Private)
- (NSDragOperation)validateFileDrop:(NSString *)path operationMask:(NSDragOperation)dragMask;
@end


@implementation KTPathInfoField

+ (Class)cellClass { return [KTPathInfoFieldCell class]; }

- (id)initWithCoder:(NSCoder *)coder
{
	// Default initialization
	[super initWithCoder:coder];
	
	// Now replace our cell with the correct subclass
	NSMutableData *cellData = [[NSMutableData alloc] init];
	NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:cellData];
	[archiver encodeObject:[self cell] forKey:@"cell"];
	[archiver finishEncoding];
	[archiver release];
	
	NSKeyedUnarchiver *unarchiver = [[NSKeyedUnarchiver alloc] initForReadingWithData:cellData];
	[unarchiver setClass:[[self class] cellClass] forClassName:@"NSTextFieldCell"];
	NSCell *cell = [unarchiver decodeObjectForKey:@"cell"];
	[unarchiver finishDecoding];
	[self setCell:cell];
	[unarchiver release];
	[cellData release];
	
	// Register for the correct drag types
	[self registerForDraggedTypes:[self supportedDragTypes]];
	
	return self;
}

#pragma mark -
#pragma mark Drag...

/*	Depending on where the mouse is clicked we either drag the file icon or start editing the text
 */
- (void)mouseDown:(NSEvent *)theEvent
{
	NSRect filenameRect = [[self cell] filenameRectForBounds:[self bounds]];
	NSRect fileIconRect = [[self cell] fileIconRectForBounds:[self bounds]];
	NSPoint mousePoint = [self convertPoint:[theEvent locationInWindow] fromView:nil];
	
	if (NSMouseInRect(mousePoint, filenameRect, [self isFlipped]))
	{
		[super mouseDown:theEvent];
	}
	else if (NSMouseInRect(mousePoint, fileIconRect, [self isFlipped]))
	{
		NSString *path = [[self cell] stringValue];
		if (path && ![path isEqualToString:@""])
		{
			// Figure out the rect to drag in; we want it to be 32 pixels square, so scale the icon rect up as needed
			float widthOutset = roundf((32.0 - fileIconRect.size.width) / 2.0);
			float heightOutset = roundf((32.0 - fileIconRect.size.height) / 2.0);
			NSRect dragRect = NSInsetRect(fileIconRect, -widthOutset, -heightOutset);
			
			[self dragFile:path fromRect:dragRect slideBack:YES event:theEvent];
		}
	}
}

#pragma mark -
#pragma mark ...and Drop
/*	By default we only accept paths, but will expand this list via delegation
 */
- (NSArray *)supportedDragTypes
{
	NSMutableArray *result = [NSMutableArray arrayWithObject:NSFilenamesPboardType];
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(supportedDragTypesForPathInfoField:)])
	{
		[result addObjectsFromArray:[delegate supportedDragTypesForPathInfoField:self]];
	}
	
	return result;
}

/*	We'll support any declared supported drag type.
 *	BUT for file paths, check they are of a supported UTI
 */
- (NSDragOperation)validateDrag:(id <NSDraggingInfo>)sender
{
	NSDragOperation result = NSDragOperationNone;
	
	NSPasteboard *pasteboard = [sender draggingPasteboard];
	if ([pasteboard availableTypeFromArray:[self supportedDragTypes]])
	{
		// Only allow through suitable file drags
		if ([pasteboard availableTypeFromArray:[NSArray arrayWithObject:NSFilenamesPboardType]])
		{
			NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
			if (files && [files count] == 1)
			{
				NSString *path = [files objectAtIndex:0];
				if (![path isEqualToString:[[self cell] stringValue]])	// Dissallow dragging the same path to us
				{
					result = [self validateFileDrop:path operationMask:[sender draggingSourceOperationMask]];
				}
			}
		}
		else
		{
			result = NSDragOperationCopy;	// Allow anything the delegate has requested
		}
	}
	
	return result;
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
	return [self validateDrag:sender];
}

- (NSDragOperation)draggingUpdated:(id < NSDraggingInfo >)sender
{
	return [self validateDrag:sender];
}

/*	Let the delegate decide what to do with the drag
 */
- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
	BOOL result = NO;
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(pathInfoField:performDragOperation:expectedDropType:)])
	{
		result = [delegate pathInfoField:self performDragOperation:sender expectedDropType:[self validateDrag:sender]];
	}
	
	return result;
}

#pragma mark -
#pragma mark Delegate

- (NSDragOperation)validateFileDrop:(NSString *)path operationMask:(NSDragOperation)dragMask
{
	NSDragOperation result = dragMask & NSDragOperationCopy;
	
	id delegate = [self delegate];
	if (delegate && [delegate respondsToSelector:@selector(pathInfoField:validateFileDrop:operationMask:)])
	{
		result = [delegate pathInfoField:self validateFileDrop:path operationMask:dragMask];
	}
	
	return result;
}

@end
