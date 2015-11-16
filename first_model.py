#early model for SVM and Linear Regression, from sklearn implementations

import os, sqlite3
import numpy as np
from sklearn import svm, linear_model
from sklearn.neighbors import KNeighborsClassifier

#code asssumes you have the ontime.sqlite3 database in pwd
#db can be downloaded from
#https://www.dropbox.com/s/69yfm1240q1am8v/ontime.sqlite3?dl=0

conn = sqlite3.connect('../data/ontime.sqlite3')
c = conn.cursor()

#build the dataset
#available fields from db table:

#year,month,dayofmonth,dayofweek,uniquecarrier,tailnum,flightnum,
#origin,dest,crsdeptime,deptime,depdelay,
#taxiout,taxiin,crsarrtime,arrtime,arrdelay,cancelled,cancellationcode,
#diverted,crselapsedtime,actualelapsedtime,airtime,distance
#carrierdelay,weatherdelay,nasdelay,securitydelay,lateaircraftdelay

data = []
#this code pulls in the entire year, and splits it to 4000000/1000000 train/test
#This takes forever to train
#it can also handle smaller portions

portion = True
if(portion):
    train_size = 2000
else:
    train_size = 4000000

if(portion):
    for row in c.execute('select * from ontime limit 2200'):
        data.append(list(row))
else:
    for row in c.execute('select * from ontime'): 
        data.append(list(row))

carriers = {'AA':1,'AS':2,'B6':3,'DL':4,'EV':5,'UA':6,'OO':7,'US':8,'VX':9,'WN':10,'F9':11,'FL':12,'HA':13,'MQ':14}

#build feature set

#TODO: bin arrdelay and depdelay for svm

X = [np.array(z[0:4] + [carriers[z[4]]]+[z[6]]+[eval(z[7])] +
              [eval(z[8])]+
              [z[14] if type(z[14]) == int else 0]+
              [z[20] if type(z[20]) == int else 0]+
              [z[23] if type(z[20]) == int else 0]).astype(float) for z in data]

y_depdelay_bins = []
y_arrdelay_bins = []

for r in data:
    dd = r[11] if type(z[11]) == int else 0
    ad = r[16] if type(z[16]) == int else 0

    #bin departure
    if dd <= 0: #on time or early
        dd_bin = 0
    elif dd <= 10: #up to 10 minutes delayed
        dd_bin = 1
    elif dd <= 30: #up to 30 minutes delayed
        dd_bin = 2
    elif dd <= 60: #up to 60 minutes delayed
        dd_bin = 3
    else: #60+ minutes delay
        dd_bin = 4

    #bin arrival
    if ad <= 0: #on time or early
        ad_bin = 0
    elif ad <= 10: #up to 10 minutes delayed
        ad_bin = 1
    elif ad <= 30: #up to 30 minutes delayed
        ad_bin = 2
    elif ad <= 60: #up to 60 minutes delayed
        ad_bin = 3
    else: #60+ minutes delay
        ad_bin = 4

    y_arrdelay_bins.append(ad_bin)
    y_depdelay_bins.append(dd_bin)
    
y_ad_bins = np.array(y_arrdelay_bins)
y_dd_bins = np.array(y_depdelay_bins)


y_cancelled = [np.array(z[17] if type(z[17]) == int else 0).astype(float) for z in data]
y_depdelay = [np.array(z[11] if type(z[11]) == int else 0).astype(float) for z in data]
y_arrdelay = [np.array(z[16] if type(z[16]) == int else 0).astype(float) for z in data]

X_train = X[0:train_size]
X_test = X[train_size:]

y_cancelled_train = y_cancelled[0:train_size]
y_cancelled_test = y_cancelled[train_size:]

#these are continuous values below we use the discrete bins
#y_depdelay_train = y_depdelay[0:train_size]
#y_depdelay_test = y_depdelay[train_size:]

#y_arrdelay_train = y_arrdelay[0:train_size]
#y_arrdelay_test = y_arrdelay[train_size:]

y_depdelay_train = y_dd_bins[0:train_size]
y_depdelay_test = y_dd_bins[train_size:]

y_arrdelay_train = y_ad_bins[0:train_size]
y_arrdelay_test = y_ad_bins[train_size:]



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
