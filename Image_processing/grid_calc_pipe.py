import skimage.io as skio
from skimage import measure
from skimage.color import rgb2gray
import matplotlib.pyplot as plt
from skimage.filters import gaussian, sobel, threshold_otsu
from scipy.ndimage import binary_closing, binary_fill_holes, label, gaussian_filter
import scipy
from skimage.morphology import disk
import numpy as np
from sklearn.cluster import KMeans
import time

img = skio.imread('data/4.jpg')
img_gray_input = rgb2gray(img[:,300:1600])

def index_plus_proche_valeur(liste, valeur_cible):
    distances = [abs(x - valeur_cible) for x in liste]
    index_plus_proche = np.argmin(distances)
    return index_plus_proche

def detect_types(img_gray):
    im_blur = gaussian(img_gray, sigma=5)
    im_sobel = sobel(im_blur)
    im_sobel = (im_sobel - im_sobel.min()) / (im_sobel.max() - im_sobel.min())
    im_thresh = im_sobel > threshold_otsu(im_sobel)
    square_size = 30
    square_structuring_element = np.ones((square_size, square_size), dtype=np.uint8)
    im_closed = binary_closing(im_thresh, structure=square_structuring_element)
    im_filled = binary_fill_holes(im_closed)
    im_labeled, num_feature = label(im_filled)
    region_props = measure.regionprops(im_labeled)

    proj_x = np.sum(im_filled, axis=0)
    proj_y = np.sum(im_filled, axis=1)
    seuil_x = max(proj_x)/2  # Seuil de détection des créneaux
    seuil_y = max(proj_y)/2
    signal_binaire_x = (proj_x > seuil_x).astype(int)
    signal_binaire_y = (proj_y > seuil_x).astype(int)
    labels_x, num_labels_x = scipy.ndimage.label(signal_binaire_x)
    labels_y, num_labels_y = scipy.ndimage.label(signal_binaire_y)
    centres_creneaux_x = [np.mean(np.where(labels_x==i)) for i in range(1,num_labels_x+1)]
    centres_creneaux_y = [np.mean(np.where(labels_y==i)) for i in range(1,num_labels_y+1)]

    region_props = measure.regionprops(im_labeled)
    centroids = [region_props[i].centroid for i in range(len(region_props))]
    more_close_x = [index_plus_proche_valeur(centres_creneaux_x, centroids[i][1]) for i in range(len(centroids))]
    more_close_y = [index_plus_proche_valeur(centres_creneaux_y, centroids[i][0]) for i in range(len(centroids))]
    label_index = []
    for i in range(len(centroids)):
        label_index.append((more_close_x[i],more_close_y[i]))
    matrix_label = np.zeros((8,8))
    for i in range(len(label_index)):
        matrix_label[label_index[i]] = i
    matrix_label = matrix_label.astype(int)
    sigma = 20
    mat_color = np.zeros((8,8))
    for i in range(8):
        for j in range(8):
            # Coordonnées du point d'intérêt (exemple : (y, x))
            point_interet = (round(region_props[matrix_label[j,i]].centroid[0]),round(region_props[matrix_label[j,i]].centroid[1]))
            case = img_gray * (im_labeled==matrix_label[j,i]+1)
            # Créer un masque gaussien 2D
            masque_gaussien = np.zeros_like(case, dtype=float)
            masque_gaussien[point_interet] = 1  # Définir le centre du masque à 1.0
            masque_gaussien = gaussian_filter(masque_gaussien, sigma=sigma)
            # Normaliser le masque gaussien pour qu'il ait des valeurs entre 0 et 1
            masque_gaussien = masque_gaussien / masque_gaussien.max()
            mat_color[i,j] = np.mean(masque_gaussien*case)
    # Redimensionnez la matrice en une seule ligne
    flat_mat = mat_color.flatten()

    # Appliquez K-means clustering en 1D avec 3 clusters (groupes)
    kmeans = KMeans(n_clusters=3)
    labels = kmeans.fit_predict(flat_mat.reshape(-1, 1))

    # Redimensionnez les labels pour correspondre à la forme d'origine de la matrice
    labels = labels.reshape(mat_color.shape)

    # Maintenant, "labels" contient les labels associés à chaque case de la matrice.
    return labels
start = time.time()
labels = detect_types(img_gray_input)
end = time.time()
print(labels)
print(end-start)

plt.figure(figsize=(10, 10))
plt.imshow(img_gray_input, cmap='gray')
plt.show()