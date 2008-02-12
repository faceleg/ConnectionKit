

#include <Cocoa/Cocoa.h>

int main (int argc, const char * argv[])
{
	if (0 == argc)
	{
		printf("\nWhat's the path to the plugins?\n");
		return 1;
	}
	const char *pluginPath = argv[0];
	NSString *basePath = [NSString stringWithUTF8String:basePath];
	NSArray *contents = [[NSFileManager fileManager] directoryContentsAtPath:basePath];
	NSEnumerator *enumerator = [contents objectEnumerator];
	NSString *fileName;

	while ((fileName = [enumerator nextObject]) != nil)
	{
		NSString *path = [basePath stringByAppendingPathComponent:fileName];
		
		
		NSLog(@"%@", path);
	}
    
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	return 0;
}
