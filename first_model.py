#early model for SVM and Linear Regression, from sklearn implementations

import os, sqlite3
import numpy as np
from sklearn import svm, linear_model

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
y_cancelled = [np.array(z[17] if type(z[17]) == int else 0).astype(float) for z in data]
y_depdelay = [np.array(z[11] if type(z[11]) == int else 0).astype(float) for z in data]
y_arrdelay = [np.array(z[16] if type(z[16]) == int else 0).astype(float) for z in data]

X_train = X[0:train_size]
X_test = X[train_size:]

y_cancelled_train = y_cancelled[0:train_size]
y_cancelled_test = y_cancelled[train_size:]

y_depdelay_train = y_depdelay[0:train_size]
y_depdelay_test = y_depdelay[train_size:]

y_arrdelay_train = y_arrdelay[0:train_size]
y_arrdelay_test = y_arrdelay[train_size:]


#departure delay
print 'predict departure delay'
clf = svm.SVC()
clf.fit(X_train,y_depdelay_train)

lreg = linear_model.LinearRegression()
lreg.fit(X_train,y_depdelay_train)

count_svm = 0
count_reg = 0

for i in range(len(X_test)):
    y = clf.predict(X_test[i])
    if y == y_depdelay_test[i]:
        count_svm += 1
    y = lreg.predict(X_test[i])
    if abs(y - y_depdelay_test[i]) < 4:
        count_reg += 1
        
#print count_svm
print '(SVM)test set correct: ' + str(count_svm * 1.0 / 200)

#print count_reg
print '(regression) test set correct: ' + str(count_reg * 1.0 / 200)


#arrival delay
print 'predict arrival delay'
clf = svm.SVC()
clf.fit(X_train,y_arrdelay_train)

lreg = linear_model.LinearRegression()
lreg.fit(X_train,y_arrdelay_train)

count_svm = 0
count_reg = 0

for i in range(len(X_test)):
    y = clf.predict(X_test[i])
    if y == y_arrdelay_test[i]:
        count_svm += 1
        
    y = lreg.predict(X_test[i])
    if abs(y - y_arrdelay_test[i]) < 4:
        count_reg += 1

       
#print count_svm
print '(SVM)test set correct: ' + str(count_svm * 1.0 / 200)

#print count_reg
print '(regression) test set correct: ' + str(count_reg * 1.0 / 200)        


#cancelled
print 'predict cancellation'
clf = svm.SVC()
clf.fit(X_train,y_cancelled_train)

lreg = linear_model.LinearRegression()
lreg.fit(X_train,y_cancelled_train)

count_svm = 0
count_reg = 0

for i in range(len(X_test)):
    y = clf.predict(X_test[i])
    if y == y_cancelled_test[i]:
        count_svm += 1
    y = lreg.predict(X_test[i])
    if abs(y - y_cancelled_test[i]) < 4:
        count_reg += 1

       
#print count_svm
print '(SVM)test set correct: ' + str(count_svm * 1.0 / 200)

#print count_reg
print '(regression) test set correct: ' + str(count_reg * 1.0 / 200)        
