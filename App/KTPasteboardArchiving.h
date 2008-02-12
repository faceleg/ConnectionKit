
@interface NSObject (KTPasteboardArchiving)
- (id <NSCoding>)pasteboardRepresentation;
- (id <NSCoding>)IDOnlyPasteboardRepresentation;
@end