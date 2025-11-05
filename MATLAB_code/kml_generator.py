from PIL import Image
import sys
import csv
import os

C1=( 0,     0,   143)
C2=( 0,    64,   255)
C3=(16,   255,   239)
C4=(207,  255,    48)
C5=(255,   96,     0)
C6=(128,    0,     0)
COLORS = [C1, C2, C3, C4, C5, C6] # matlab jet colors
#COLORS = [BLUE, RED]    # smaller values will be more of the first color and vice versa

# CONSTANTS//GLOBALS
EPSILON = sys.float_info.epsilon
#RED = (255, 0, 0)
#GREEN = (0, 255, 0)
#BLUE = (0, 0, 255)
#YELLOW=(255, 255, 0)
#BLACK= (0,0,0)
#COLORS = [BLUE, RED]    # smaller values will be more of the first color and vice versa
#COLORS = [BLACK, BLUE, YELLOW, RED]    # smaller values will be more of the first color and vice versa

#COLORS = [YELLOW, GREEN]    # smaller values will be more of the first color and vice versa
IMAGE = 'scatter.png'
PICTURE = Image.open(IMAGE)

# returns path to a recolorized scatter.png based on rsrp_value
def get_image(rsrp_value, min_val, max_val, image_path='images'):
    width, height = PICTURE.size
    new_color, name = generate_color(rsrp_value, min_val, max_val)
    picture_name = "{}.png".format(name)
    picture_path = os.path.join(os.getcwd(), image_path, picture_name)
    if os.path.exists(picture_path):
        return picture_path
    new_image = Image.new('RGBA', (width, height))
    pixels = new_image.load()
    for x in range(width - 1):
        for y in range(height - 1):
            color = PICTURE.getpixel((x, y))
            if color != 0:
                pixels[x, y] = (new_color)

    new_image.save(picture_path)

    return picture_path

# returns tuple of color values and combined hex value
# color is based on rsrp_value and which colors in COLORS constant
#def generate_color(val, min_val = -70, max_val = -10, colors = COLORS):
def generate_color(val, min_val = -30, max_val = 30, colors = COLORS):
    i_f = float(val - min_val) / float(max_val - min_val) * (len(colors) - 1)
    i, f = int(i_f // 1), i_f % 1
    if f < EPSILON:
        r, g, b = colors[i]
        rgb = '0x' + ''.join('{:02X}{:02X}{:02X}'.format(r, g, b))
        return (r, g, b), rgb
    else:
        (r1, g1, b1), (r2, g2, b2) = colors[i], colors[i + 1]
        r, g, b = int(r1 + f * (r2 - r1)), int(g1 + f * (g2 - g1)), int(b1 + f * (b2 - b1))
        rgb = '0x' + ''.join('{:02X}{:02X}{:02X}'.format(r, g, b))
        return (r, g, b), rgb

# writes a line of data to kml file specified by second command line argument
# i=> iteration number(required for correct kml generation), scale=> size of icon, icon=> icon file path
def kml_gen(name, i, time, lon, lat, alt = 0, rsrp = 0, scale = 1, icon = '1'):
    lon = str(lon)
    lat = str(lat)
    alt = str(alt)
    rsrp = str(rsrp)
    if icon == '1':
        icon = IMAGE                # sets icon to default color when no path for a color graded icon is available

    if (os.path.isfile(name) == 0): # creates kml data file and adds starting code if it does not exist
        new_kml = open(name, "w+")
        new_kml.write('<?xml version="1.0" encoding="UTF-8"?>\r')
        new_kml.write('<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">\r')
        new_kml.write('    <Document id="1">\r')
        new_kml.close()
        print('new file "%s" has been made' % name)
    else:
        with open(name, 'rb+') as filehandle:  # removes last 2 lines of kml headers so new data points can be added
            filehandle.seek(-22, os.SEEK_END)
            filehandle.truncate()

    kml = open(name, "a+")

    kml.write('       <Style id="%d">\r' % (i + 1))
    kml.write('            <IconStyle id="10">\r')
    kml.write('                <colorMode>normal</colorMode>\r')
    kml.write('                <scale>%d</scale>\r' % scale)
    kml.write('                <heading>0</heading>\r')
    kml.write('                <Icon id="%d">\r' % (i + 2))
    kml.write('                    <href>%s</href>\r' % icon)
    kml.write('                </Icon>\r')
    kml.write('            </IconStyle>\r')
    kml.write('        </Style>\r')

    kml.write('		<Placemark id="18">\r')
    kml.write('            <description>%s,%s</description>\r' % (rsrp, time))
    kml.write('            <TimeStamp>\r')
    kml.write('                <when>%s</when>\r' % time)
    kml.write('            </TimeStamp>\r')
    kml.write('            <styleUrl>#%d</styleUrl>\r' % (i + 1))
    kml.write('            <Point id="17">\r')
    kml.write('                <coordinates>%s,%s,%s</coordinates>\r' % (lon, lat, alt))
    kml.write('                <altitudeMode>relativeToGround</altitudeMode>\r')
    kml.write('            </Point>\r')
    kml.write('        </Placemark>\r')
    kml.write('    </Document>\r')
    kml.write('</kml>\r')

    kml.close()

    print('point # %d at %s , %s , %s has been added' % (i, lon, lat, alt))

def convert_data(input_file, output_path, image_path="images"):
    # create directory for scatter images if not present
    if not os.path.isdir(image_path):
        os.mkdir(image_path)

    # generate images and pass data to kml_gen for each row of data
    for _ in range(0, 1):
        raw = open(input_file, 'r')     # first command line argument is input file name
        min_val = float([i for i in csv.reader(raw)][0][5])
        max_val = min_val
        raw.seek(0)                     # return to beginning of file
        for row in csv.reader(raw):     # find min and max value of rsrp value
            if float(row[5]) < min_val:
                min_val = float(row[5])
            if float(row[5]) > max_val:
                max_val = float(row[5])
        raw.seek(0)
        for row in csv.reader(raw):
            icon = get_image(float(row[5]), min_val, max_val, image_path)
            kml_gen(output_path, int(row[0]), row[1], row[2], row[3], row[4], row[5], 1, icon)
        raw.close()

if __name__ == "__main__":
    from argparse import ArgumentParser

    parser = ArgumentParser()
    parser.add_argument("--input", help="input (csv) file", required=True)
    parser.add_argument("--output", help="output (kml) file", required=True)
    parser.add_argument("--images", help="scatter image folder", required=False, default="images")
    args = parser.parse_args()

    convert_data(args.input, args.output, args.images)
