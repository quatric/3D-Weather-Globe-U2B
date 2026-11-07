#import "WeatherGlobePrefix.h"


@interface TextFieldCell : NSTextFieldCell
{
}
- (void)drawWithFrame:(NSRect)aFrame inView:(id)aView;
- (void)endEditing:(id)aEditing;
- (void)selectWithFrame:(NSRect)aFrame inView:(id)aView editor:(id)aEditor delegate:(id)aDelegate start:(NSInteger)aStart length:(NSInteger)aLength;
@end

