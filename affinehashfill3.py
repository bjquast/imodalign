# Fill in a dictionary with filepath as key
# and the affine as value,
# such as [1, 0, 0, 1, 0, 0] for the identity affine


# Read the affines from a file

fobj = open("/media/bquast/usb3_1tb/Pedentontus_californicus/imod_transformations.txt", "r")
affines = {}
for line in fobj:
    affineline = line.split() 
    affines[affineline[0]] = [affineline[1],affineline[2],affineline[3],affineline[4],affineline[5],affineline[6]]
fobj.close()





# ...
# ...


# Apply the affine to every Patch
from ini.trakem2.display import Display, Patch
from java.awt.geom import AffineTransform

for layer in Display.getFront().getLayerSet().getLayers():
  for patch in layer.getDisplayables(Patch):
    filepath = patch.getImageFilePath()
    print ("filepath\n")
    affine = affines.get(filepath, None) #filepath statt affines eingefuegt
    if affine:
    	for index in range (0,6):
    		affine[index] = float(affine[index])
    		print ("affine[index]", index, affine[index])
    	patch.setAffineTransform(AffineTransform(affine[0], affine[1],affine[2], affine[3], (affine[4]), affine[5]))
    else:
    	print "No affine for filepath:", filepath
    print ("done\n")