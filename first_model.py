#early model for SVM and Linear Regression, from sklearn implementations

import os, sqlite3, csv
import numpy as np
from sklearn import svm, linear_model
from sklearn.neighbors import KNeighborsClassifier

#code asssumes you have the features.csv file in ../data
#db can be downloaded from
#https://www.dropbox.com/s/hzy1hcsu71lufs2/features.csv?dl=0

X_in = []
y_in = []
with open('../data/features.csv','r') as infile:
    csvreader = csv.reader(infile)
    next(csvreader,None)
    for row in csvreader:
        X_in.append(row[:-3])
        y_in.append(row[-3:])

#this code pulls in the entire year, and splits it to 4000000/1000000 train/test
#This takes forever to train
#it can also handle smaller portions

portion = True
if(portion):
    X = X_in[:2200]
    y=y_in[:2200]
    train_size = 2000
else:
    train_size = 4000000

y_dd = [z[0] for z in y]
y_ad = [z[1] for z in y]
y_c = [z[2] for z in y]

X_train = X[0:train_size]
X_test = X[train_size:]

y_depdelay_train = y_dd[0:train_size]
y_depdelay_test = y_dd[train_size:]

y_arrdelay_train = y_ad[0:train_size]
y_arrdelay_test = y_ad[train_size:]

y_cancelled_train = y_c[0:train_size]
y_cancelled_test = y_c[train_size:]

#departure delay
print 'predict departure delay'

clf = svm.SVC()
clf.fit(X_train,y_depdelay_train)

neigh = KNeighborsClassifier(n_neighbors=3)
neigh.fit(X_train,y_depdelay_train)

count_svm = 0
count_knn = 0

for i in range(len(X_test)):
    y = clf.predict(X_test[i])
    if y == y_depdelay_test[i]:
        count_svm += 1
    y = neigh.predict(X_test[i])

    if y == y_depdelay_test[i]:
        count_knn += 1
        
#print count_svm
print '(SVM)test set correct: ' + str(count_svm * 1.0 / 200)

#print count_reg
print '(KNN) test set correct: ' + str(count_knn * 1.0 / 200)


#arrival delay
print 'predict arrival delay'

clf = svm.SVC()
clf.fit(X_train,y_arrdelay_train)

neigh = KNeighborsClassifier(n_neighbors=3)
neigh.fit(X_train,y_arrdelay_train)

count_svm = 0
count_knn = 0

for i in range(len(X_test)):
    y = clf.predict(X_test[i])
    if y == y_arrdelay_test[i]:
        count_svm += 1
        
    y = neigh.predict(X_test[i])
    if y == y_depdelay_test[i]:
        count_knn += 1

       
#print count_svm
print '(SVM)test set correct: ' + str(count_svm * 1.0 / 200)

#print count_reg
print '(KNN) test set correct: ' + str(count_knn * 1.0 / 200)        


#cancelled
print 'predict cancellation'

clf = svm.SVC()
clf.fit(X_train,y_cancelled_train)

neigh = KNeighborsClassifier(n_neighbors=3)
neigh.fit(X_train,y_cancelled_train)

count_svm = 0
count_knn = 0

for i in range(len(X_test)):
    y = clf.predict(X_test[i])
    if y == y_cancelled_test[i]:
        count_svm += 1

    y = neigh.predict(X_test[i])
    if y == y_cancelled_test[i]:
        count_knn += 1

       
#print count_svm
print '(SVM)test set correct: ' + str(count_svm * 1.0 / 200)

#print count_reg
print '(KNN) test set correct: ' + str(count_knn * 1.0 / 200)        
