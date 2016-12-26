#import "NSExpression+MGLAdditions.h"

@implementation NSExpression (MGLAdditions)

- (std::vector<mbgl::Value>)mgl_filterValues
{
    if ([self.constantValue isKindOfClass:[NSArray class]] || [self.constantValue isKindOfClass:[NSSet class]]) {
        std::vector<mbgl::Value> convertedValues;
        for (id item in self.constantValue) {
            id constantValue = item;
            if ([item isKindOfClass:[NSExpression class]]) {
                constantValue = [constantValue constantValue];
            }
            convertedValues.push_back([self mgl_convertedValueWithValue:constantValue]);
        }
        return convertedValues;
    }
    [NSException raise:NSInvalidArgumentException
                format:@"Constant value expression must contain an array or set."];
    return { };
}

- (mbgl::Value)mgl_filterValue
{
    return [self mgl_convertedValueWithValue:self.constantValue];
}

- (mbgl::Value)mgl_convertedValueWithValue:(id)value
{
    if ([value isKindOfClass:NSString.class]) {
        return { std::string([(NSString *)value UTF8String]) };
    } else if ([value isKindOfClass:NSNumber.class]) {
        NSNumber *number = (NSNumber *)value;
        if ((strcmp([number objCType], @encode(char)) == 0) ||
            (strcmp([number objCType], @encode(BOOL)) == 0)) {
            // char: 32-bit boolean
            // BOOL: 64-bit boolean
            return { (bool)number.boolValue };
        } else if (strcmp([number objCType], @encode(double)) == 0) {
            // Double values on all platforms are interpreted precisely.
            return { (double)number.doubleValue };
        } else if (strcmp([number objCType], @encode(float)) == 0) {
            // Float values when taken as double introduce precision problems,
            // so warn the user to avoid them. This would require them to
            // explicitly use -[NSNumber numberWithFloat:] arguments anyway.
            // We still do this conversion in order to provide a valid value.
            static dispatch_once_t onceToken;
            dispatch_once(&onceToken, ^{
                NSLog(@"Float value in expression will be converted to a double; some imprecision may result. "
                      @"Use double values explicitly when specifying constant expression values and "
                      @"when specifying arguments to predicate and expression format strings. "
                      @"This will be logged only once.");
            });
            return { (double)number.doubleValue };
        } else if ([number compare:@(0)] == NSOrderedDescending ||
                   [number compare:@(0)] == NSOrderedSame) {
            // Positive integer or zero; use uint64_t per mbgl::Value definition.
            // We use unsigned long long here to avoid any truncation.
            return { (uint64_t)number.unsignedLongLongValue };
        } else if ([number compare:@(0)] == NSOrderedAscending) {
            // Negative integer; use int64_t per mbgl::Value definition.
            // We use long long here to avoid any truncation.
            return { (int64_t)number.longLongValue };
        }
    } else if (value && value != [NSNull null]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"Can’t convert %s:%@ to mbgl::Value", [value objCType], value];
    }
    return { };
}

- (mbgl::FeatureIdentifier)mgl_featureIdentifier
{
    id value = self.constantValue;
    mbgl::Value mbglValue = [self mgl_filterValue];
    
    if ([value isKindOfClass:NSString.class]) {
        return mbglValue.get<std::string>();
    } else if ([value isKindOfClass:NSNumber.class]) {
        NSNumber *number = (NSNumber *)value;
        if ((strcmp([number objCType], @encode(char)) == 0) ||
            (strcmp([number objCType], @encode(BOOL)) == 0)) {
            return mbglValue.get<bool>();
        } else if ( strcmp([number objCType], @encode(double)) == 0 ||
                    strcmp([number objCType], @encode(float)) == 0) {
            return mbglValue.get<double>();
        } else if ([number compare:@(0)] == NSOrderedDescending ||
                   [number compare:@(0)] == NSOrderedSame) {
            return mbglValue.get<uint64_t>();
        } else if ([number compare:@(0)] == NSOrderedAscending) {
            return mbglValue.get<int64_t>();
        }
    }
    
    return {};
}

@end
