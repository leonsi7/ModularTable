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
from matplotlib.colors import ListedColormap
import cv2

img = skio.imread('data/4.jpg')
image_references = [(5, 0), (6, 0), (7, 0)]  # Blanc, Gris, Noir
reference_histograms = [[0, 1], [0.5, 0.5], [1, 0]]
colors = ['blue', 'yellow', 'green']


def index_plus_proche_valeur(liste, valeur_cible, img_gray):
    distances = [abs(x - valeur_cible) for x in liste]
    index_plus_proche = np.argmin(distances)
    if distances[index_plus_proche] > int(len(img_gray)/(16*2)):
        return 8
    return index_plus_proche


def detect_types(img_gray):
    im_blur = gaussian(img_gray, sigma=3)
    im_sobel = sobel(im_blur)
    im_sobel = (im_sobel - im_sobel.min()) / (im_sobel.max() - im_sobel.min())
    im_thresh = im_sobel > threshold_otsu(im_sobel)
    square_size = int(len(img_gray)/(17*2))
    square_structuring_element = np.ones(
        (square_size, square_size), dtype=np.uint8)
    im_closed = binary_closing(im_thresh, structure=square_structuring_element)
    im_filled = binary_fill_holes(im_closed)
    im_labeled, num_feature = label(im_filled)
    region_props = measure.regionprops(im_labeled)

    proj_x = np.sum(im_filled, axis=0)
    proj_y = np.sum(im_filled, axis=1)
    seuil_x = max(proj_x)/2  # Seuil de détection des créneaux
    seuil_y = max(proj_y)/2
    signal_binaire_x = (proj_x > seuil_x).astype(int)
    signal_binaire_y = (proj_y > seuil_y).astype(int)
    labels_x, num_labels_x = scipy.ndimage.label(signal_binaire_x)
    labels_y, num_labels_y = scipy.ndimage.label(signal_binaire_y)
    centres_creneaux_x = [np.mean(np.where(labels_x == i))
                          for i in range(1, num_labels_x+1)]
    centres_creneaux_y = [np.mean(np.where(labels_y == i))
                          for i in range(1, num_labels_y+1)]

    region_props = measure.regionprops(im_labeled)
    centroids = [region_props[i].centroid for i in range(len(region_props))]
    more_close_x = [index_plus_proche_valeur(
        centres_creneaux_x, centroids[i][1], img_gray) for i in range(len(centroids))]
    more_close_y = [index_plus_proche_valeur(
        centres_creneaux_y, centroids[i][0], img_gray) for i in range(len(centroids))]
    label_index = []
    for i in range(len(centroids)):
        label_index.append((more_close_x[i], more_close_y[i]))
    matrix_label = np.zeros((8, 8))
    for i in range(len(label_index)):
        if 0 <= label_index[i][0] < matrix_label.shape[0] and 0 <= label_index[i][1] < matrix_label.shape[1]:
            matrix_label[label_index[i]] = i
    matrix_label = matrix_label.astype(int)

    img_gray = (img_gray*255).astype(int)
    # reference_histograms_unormalized = [np.bincount(img_gray[im_labeled==matrix_label[index]+1].ravel(), minlength=256) for index in image_references]
    # reference_histograms_unormalized_simplified = [np.array([np.sum(hist[:80]), np.sum(hist[180:])]) for hist in reference_histograms_unormalized]
    # reference_histograms = [x/np.sum(x) for x in reference_histograms_unormalized_simplified]
    print(reference_histograms)

    labels = np.zeros((8, 8), dtype=int)
    for i in range(8):
        for j in range(8):
            case = img_gray[im_labeled == matrix_label[i, j]+1]
            histogram = np.bincount(case.ravel(), minlength=256)
            histogram = np.array(
                [np.sum(histogram[:80]), np.sum(histogram[180:])])
            histogram = histogram/np.sum(histogram)
            distances = [np.sum((histogram - reference_histogram)**2 / (histogram +
                                reference_histogram + 1e-10)) for reference_histogram in reference_histograms]
            labels[j, i] = np.argmin(distances)
    return labels


def get_labels(img_file):
    img = skio.imread(img_file)
    img_gray_input = rgb2gray(img)
    plt.imshow(img_gray_input, cmap='gray')
    plt.show()

    labels = detect_types(img_gray_input)
    cmap = ListedColormap(colors)
    plt.imshow(labels, cmap=cmap, interpolation='nearest')
    plt.show()


def use_camera():
    cap1 = cv2.VideoCapture(1)
    list_matrix_changes = []
    if not cap1.isOpened():
        print("La webcam n'a pas pu être ouverte. Assurez-vous qu'elle est branchée et fonctionne correctement.")
    else:
        # Capturez continuellement des images depuis la webcam.
        print("Camera stream launched")
        while True:
            ret, frame = cap1.read()  # Lisez une image depuis la webcam.
            print_matrix_label = np.zeros((8, 8), dtype=int)
            if not ret:
                print("Échec de la capture de l'image depuis la webcam.")
                break

            if cv2.waitKey(1) & 0xFF == ord('q'):
                break
            
            img_gray_input = rgb2gray(frame[:, 50:1600])
            cv2.imshow("Webcam", img_gray_input)
            start2 = time.time()
            new_labels = detect_types(img_gray_input)
            start4 = time.time()
            print(new_labels)
            list_matrix_changes.append(new_labels)
            update_gama = False
            start = time.time()
            for i in range(8):
                for j in range(8):
                    label_0 = list_matrix_changes[0][i, j]
                    change = True
                    for index in range(len(list_matrix_changes)):
                        if list_matrix_changes[index][i, j] != label_0:
                            change = False
                    if change == True:
                        print_matrix_label[i, j] = label_0
                        update_gama = True
            if len(list_matrix_changes) > 10:
                list_matrix_changes.pop(0)
            start3 = time.time()

            if update_gama:
                value_to_replacement = {0: 'c', 1: 'i', 2: 'r'}
                converted_matrix = np.vectorize(
                    value_to_replacement.get)(print_matrix_label)
                # Save the converted matrix to a CSV file
                file_name = 'input_building_layout.csv'
                np.savetxt(file_name, converted_matrix,
                           delimiter=';', fmt='%s')
                print(converted_matrix)

            start4 = time.time
            print(start2-start4)

            cmap = ListedColormap(colors)
            plt.imshow(print_matrix_label, cmap=cmap, interpolation='nearest')
            plt.axis('off')
            fig = plt.gcf()
            fig.canvas.draw()
            img_array = np.array(fig.canvas.renderer.buffer_rgba())
            img_bgr = cv2.cvtColor(img_array, cv2.COLOR_RGBA2BGR)
            cv2.imshow("Label", img_bgr)

        cap1.release()
        cv2.destroyAllWindows()

    # labels = detect_types(img_gray_input)
    # cmap = ListedColormap(colors)
    # plt.imshow(labels, cmap=cmap, interpolation='nearest')
    # plt.show()


if __name__ == "__main__":
    use_camera()
