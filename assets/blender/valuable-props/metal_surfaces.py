"""Authored deterministic machining grain, exported as ordinary glTF PBR maps."""
import math
import random
import bpy


def apply_metal_surfaces(materials, output):
    output.mkdir(exist_ok=True)
    size = 512
    for name, base in [('silver', .28), ('gold', .25)]:
        rng = random.Random(1907 if name == 'silver' else 1927)
        grain = [rng.uniform(-1, 1) for _ in range(size)]
        # Sparse hairline marks interrupt the machining grain. No geometry or rules change.
        scratches = [(rng.randrange(size), rng.randrange(size), rng.randrange(35, 100))
                     for _ in range(24)]
        height = [[.0008 * grain[y] + .0002 * math.sin(x * .17 + y)
                   for x in range(size)] for y in range(size)]
        for x, y, length in scratches:
            for step in range(length):
                height[(y + step // 10) % size][(x + step) % size] -= .0015
        rough_pixels, normal_pixels = [], []
        for y in range(size):
            for x in range(size):
                rough = max(.12, min(.48, base + .025 * grain[y]
                                    + .008 * math.sin(x * .17 + y)))
                rough_pixels.extend((rough, rough, rough, 1))
                dx = (height[y][(x + 1) % size] - height[y][(x - 1) % size]) * 8
                dy = (height[(y + 1) % size][x] - height[(y - 1) % size][x]) * 8
                inv = 1 / math.sqrt(dx * dx + dy * dy + 1)
                normal_pixels.extend((.5 - dx * inv / 2, .5 - dy * inv / 2,
                                      .5 + inv / 2, 1))
        nodes = materials[name].node_tree.nodes
        links = materials[name].node_tree.links
        shader = nodes.get('Principled BSDF')
        for channel, pixels in [('roughness', rough_pixels), ('normal', normal_pixels)]:
            image = bpy.data.images.new(name + '-' + channel, size, size)
            image.colorspace_settings.name = 'Non-Color'
            image.pixels.foreach_set(pixels)
            image.filepath_raw = str(output / (name + '-' + channel + '.png'))
            image.file_format = 'PNG'
            image.save()
            image.pack()
            texture = nodes.new('ShaderNodeTexImage')
            texture.image = image
            texture.label = 'Machining ' + channel
            if channel == 'roughness':
                links.new(texture.outputs['Color'], shader.inputs['Roughness'])
            else:
                normal = nodes.new('ShaderNodeNormalMap')
                links.new(texture.outputs['Color'], normal.inputs['Color'])
                links.new(normal.outputs['Normal'], shader.inputs['Normal'])
