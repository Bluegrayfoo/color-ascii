#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>
#import <sys/ioctl.h>
#import <unistd.h>

typedef struct {
    const char *imagePath;
    int columns;
    int rows;
    bool truecolor;
} Options;

static void usage(void) {
    fprintf(stderr,
        "Usage: ascii image [--cols n] [--rows n] [--truecolor]\n\n"
        "Renders PNG, JPEG, HEIC, TIFF, GIF, BMP, and other macOS-readable image files\n"
        "as colored Unicode full-block characters.\n");
    exit(1);
}

static int parsePositiveInt(const char *text) {
    char *end = NULL;
    long value = strtol(text, &end, 10);
    if (end == text || *end != '\0' || value <= 0 || value > INT_MAX) {
        usage();
    }
    return (int)value;
}

static Options parseOptions(int argc, const char **argv) {
    Options options = {0};

    for (int i = 1; i < argc; i++) {
        const char *argument = argv[i];

        if (strcmp(argument, "-h") == 0 || strcmp(argument, "--help") == 0) {
            usage();
        } else if (strcmp(argument, "--cols") == 0 || strcmp(argument, "--width") == 0) {
            if (++i >= argc) usage();
            options.columns = parsePositiveInt(argv[i]);
        } else if (strcmp(argument, "--rows") == 0 || strcmp(argument, "--height") == 0) {
            if (++i >= argc) usage();
            options.rows = parsePositiveInt(argv[i]);
        } else if (strcmp(argument, "--truecolor") == 0) {
            options.truecolor = true;
        } else {
            if (argument[0] == '-' || options.imagePath != NULL) {
                usage();
            }
            options.imagePath = argument;
        }
    }

    if (options.imagePath == NULL) {
        usage();
    }

    return options;
}

static void terminalSize(int *columns, int *rows) {
    struct winsize size;
    if (ioctl(STDOUT_FILENO, TIOCGWINSZ, &size) == 0 && size.ws_col > 0 && size.ws_row > 0) {
        *columns = size.ws_col;
        *rows = size.ws_row;
        return;
    }

    const char *envColumns = getenv("COLUMNS");
    const char *envRows = getenv("LINES");
    *columns = envColumns ? atoi(envColumns) : 200;
    *rows = envRows ? atoi(envRows) : 100;

    if (*columns <= 0) *columns = 200;
    if (*rows <= 0) *rows = 100;
}

static int squaredDistance(int r1, int g1, int b1, int r2, int g2, int b2) {
    int dr = r1 - r2;
    int dg = g1 - g2;
    int db = b1 - b2;
    return dr * dr + dg * dg + db * db;
}

static int closestANSI256Color(int r, int g, int b) {
    const int levels[6] = {0, 95, 135, 175, 215, 255};
    int bestIndex = 16;
    int bestDistance = INT_MAX;

    for (int ri = 0; ri < 6; ri++) {
        for (int gi = 0; gi < 6; gi++) {
            for (int bi = 0; bi < 6; bi++) {
                int distance = squaredDistance(r, g, b, levels[ri], levels[gi], levels[bi]);
                if (distance < bestDistance) {
                    bestDistance = distance;
                    bestIndex = 16 + 36 * ri + 6 * gi + bi;
                }
            }
        }
    }

    for (int grayIndex = 0; grayIndex < 24; grayIndex++) {
        int gray = 8 + grayIndex * 10;
        int distance = squaredDistance(r, g, b, gray, gray, gray);
        if (distance < bestDistance) {
            bestDistance = distance;
            bestIndex = 232 + grayIndex;
        }
    }

    return bestIndex;
}

int main(int argc, const char **argv) {
    @autoreleasepool {
        Options options = parseOptions(argc, argv);

        int terminalColumns = 0;
        int terminalRows = 0;
        terminalSize(&terminalColumns, &terminalRows);
        if (options.columns > 0) terminalColumns = options.columns;
        if (options.rows > 0) terminalRows = options.rows;

        NSString *rawPath = [NSString stringWithUTF8String:options.imagePath];
        NSString *path = [rawPath stringByExpandingTildeInPath];
        NSImage *image = [[NSImage alloc] initWithContentsOfFile:path];
        if (!image) {
            fprintf(stderr, "Could not open image.\n");
            return 1;
        }

        CGImageRef sourceImage = [image CGImageForProposedRect:NULL context:nil hints:nil];
        if (!sourceImage) {
            fprintf(stderr, "Could not convert image.\n");
            return 1;
        }

        size_t sourceWidth = CGImageGetWidth(sourceImage);
        size_t sourceHeight = CGImageGetHeight(sourceImage);
        if (sourceWidth == 0 || sourceHeight == 0) {
            fprintf(stderr, "Image has no readable pixels.\n");
            return 1;
        }

        double characterAspect = 0.50;
        int width = terminalColumns > 1 ? terminalColumns - 1 : 1;
        int uncappedHeight = (int)((double)sourceHeight / (double)sourceWidth * (double)width * characterAspect);
        if (uncappedHeight < 1) uncappedHeight = 1;

        int height = uncappedHeight;
        int maxRows = terminalRows > 1 ? terminalRows - 1 : 1;
        if (height > maxRows) height = maxRows;

        int actualWidth = width;
        if (height < uncappedHeight) {
            actualWidth = (int)((double)height / (double)sourceHeight * (double)sourceWidth / characterAspect);
            if (actualWidth < 1) actualWidth = 1;
        }

        size_t bytesPerPixel = 4;
        size_t bytesPerRow = (size_t)actualWidth * bytesPerPixel;
        size_t pixelCount = (size_t)actualWidth * (size_t)height * bytesPerPixel;
        unsigned char *pixels = calloc(pixelCount, sizeof(unsigned char));
        if (!pixels) {
            fprintf(stderr, "Could not allocate pixel buffer.\n");
            return 1;
        }

        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        CGBitmapInfo bitmapInfo = kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big;
        CGContextRef context = CGBitmapContextCreate(
            pixels,
            actualWidth,
            height,
            8,
            bytesPerRow,
            colorSpace,
            bitmapInfo
        );
        CGColorSpaceRelease(colorSpace);

        if (!context) {
            free(pixels);
            fprintf(stderr, "Could not create graphics context.\n");
            return 1;
        }

        CGContextSetInterpolationQuality(context, kCGInterpolationHigh);
        CGContextDrawImage(context, CGRectMake(0, 0, actualWidth, height), sourceImage);

        printf("\033[2J\033[H");

        for (int y = 0; y < height; y++) {
            int lastColor = -1;
            int lastR = -1;
            int lastG = -1;
            int lastB = -1;

            for (int x = 0; x < actualWidth; x++) {
                size_t index = ((size_t)y * (size_t)actualWidth + (size_t)x) * bytesPerPixel;
                int r = pixels[index];
                int g = pixels[index + 1];
                int b = pixels[index + 2];

                if (options.truecolor) {
                    if (r != lastR || g != lastG || b != lastB) {
                        printf("\033[38;2;%d;%d;%dm", r, g, b);
                        lastR = r;
                        lastG = g;
                        lastB = b;
                    }
                } else {
                    int color = closestANSI256Color(r, g, b);
                    if (color != lastColor) {
                        printf("\033[38;5;%dm", color);
                        lastColor = color;
                    }
                }

                fputs("█", stdout);
            }

            fputs("\033[0m\n", stdout);
            fflush(stdout);
        }

        CGContextRelease(context);
        free(pixels);
    }

    return 0;
}
