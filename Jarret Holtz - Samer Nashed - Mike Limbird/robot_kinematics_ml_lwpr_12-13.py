import time
'''
1. Locally weighted progression regression for kinematics of a soccer robot

-- Changes to make
	1. Calculate velocity for each time step and store it to file to use in calculations
'''

def is_float(str):
	try:
		float(str)
		return True
	except ValueError:
		return False

from lwpr import *
from numpy import *
from random import *
from math import *
import numpy as np

INPUT_DIM  = 4 #(3 for pose, 3 for velocity, 3 for command)
OUTPUT_DIM = 1  #(3 for pose, 3 for velocity)
COMMAND_START = 7 # After time (removed), pose, and velocity
STEP_SIZE = 1 # Used to determine time comparison 

SET_REDUCTION = 1 # make the sets smaller just to speed training

R = Random()
x = zeros(INPUT_DIM )
y = zeros(OUTPUT_DIM)

def transformCommand(pose, command):
	theta =  -pose[2]
	#theta = (angle/180.) * numpy.pi
	rotMatrix = np.array([[np.cos(theta), -np.sin(theta)], 
                         [np.sin(theta),  np.cos(theta)]])
	command[0:2] = np.dot(rotMatrix, command[0:2])

	return command

#LOAD DATA FROM FILES
def load_data_in_array(filename, fill_array):
	with open(filename, "r") as f:
		last_line = []
		skip = False
		for line in f:
			skip = False
			vals_str = line.split(",")
			# 10 elements, 1 for time, 3 for pose, 3 for velocity (although it gets replaced), and 3 for command
			vals = [float(x) for x in vals_str if is_float(x)]
			if len(vals) == 10:
				vals = array(vals)
				out = []
				#Calculate delta_t and the velocities, keep this out of lower loops
				if last_line != []: 
					# Necessary to get delta_t
					time_x = vals[0]
					time_y = last_line[0]
					pose_x = vals[1:4]
					

					pose_y = last_line[1:4]
					delta_t = time_x - time_y
					out.append(delta_t)
					out = append(out, pose_x)
					# Calculate Velocity
					z = pose_x - pose_y
					##print time_y
					if delta_t == 0.0:
						skip = True
					else:	
						z = z / delta_t 
					out = append(out, z)
					# Replace tracker velocity with calculated velocity
					command = transformCommand(pose_x, vals[7:])
					#print command
					out = append(out, command)
					# Replace time with delta t
					#vals[0] = delta_t
				last_line = vals
				# Pop delta_t and add to our actual array
				#vals = np.delete(vals, 0)
				if not skip:
					if out != []:
						fill_array.append(array(out))		
	return fill_array

best_sum = 50000000
best_index = 0
for iter in range(1,2):
	model = LWPR(INPUT_DIM, OUTPUT_DIM) #input, output dimentions, correlate current state + action to new current state
	model2 = LWPR(INPUT_DIM, OUTPUT_DIM) #input, output dimentions, correlate current state + action to new current state
	STEP_SIZE = 0
	print iter
	data = load_data_in_array("robot_0_1.txt", [])
	train_data = data[:len(data)/2]
	test_data = data[len(data)/2:]

	print "normalising"
	col_mean = mean(train_data, axis=0)
	print "After Mean"
	col_var = var(train_data, axis=0)
	col_max = amax(train_data, axis=0)
	col_min = amin(train_data, axis=0)
	col_rge = ptp(train_data, axis=0)
	print "col_mean", col_mean
	print "col_var ", col_var
	print "col_max ", col_max
	print "col_min ", col_min
	print "col_rge ", col_rge

	print "train_data size = ", len(train_data)
	print "test_data size = ", len(test_data)

	model.norm_in = col_rge[0:INPUT_DIM] + 10
	model.norm_out = col_rge[1:OUTPUT_DIM + 1] + 10
	model2.norm_in = col_rge[0:INPUT_DIM] + 10
	model2.norm_out = col_rge[2:OUTPUT_DIM + 2] + 10


	print "setup"

	model.update_D = True
	model.init_D = (10 * iter) * eye(INPUT_DIM) #found by empirical trial and error starting at 0.01, with updateD false
	model.diag_only = False
	model.init_alpha = ones([INPUT_DIM, INPUT_DIM])
	model.kernel = "BiSquare"
	model.meta = True
	model2.update_D = True
	model2.init_D = (1000 * iter) * eye(INPUT_DIM) #found by empirical trial and error starting at 0.01, with updateD false
	model2.diag_only = False
	#model2.init_alpha = ones([INPUT_DIM, INPUT_DIM])
	#model2.kernel = "BiSquare"
	model2.meta = True
	print "penalty ", model.penalty
	#model.penalty = .01
	print "updating model..."
	sum = 0
	n = 0
	n2 = 0
	tic = time.clock()
	for i in range((len(train_data) - (STEP_SIZE + 1) ) / SET_REDUCTION):
		# Get all x inputs except for command
		x = train_data[i + STEP_SIZE * SET_REDUCTION][0:INPUT_DIM]
		# Get all y outputs
		y_x = train_data[i + STEP_SIZE + 1 * SET_REDUCTION][1:OUTPUT_DIM + 1]
		y_y = train_data[i + STEP_SIZE + 1 * SET_REDUCTION][2:OUTPUT_DIM + 2]
		# Get the command
		command = train_data[i + STEP_SIZE + 1 * SET_REDUCTION][COMMAND_START:]
		#pose = train_data[i + STEP_SIZE + 1 * SET_REDUCTION][0:3]
		#pose = x[1:4]

		# Add command to inputs
		#x = np.append(x,command)
		y_x_predict = model.update(x, y_x)	
		#y_y_predict = model2.update(x,y_y)
		error = linalg.norm(y_x - y_x_predict)
		error2 = error * error
		sum += error2
		n += 1
		mse = sum / n
		with open("training_error.txt", "a") as myfile:
			myfile.write(str(mse) + '\n')

		# if y_x_predict == y_y_predict == 0:
		# 	print "-----------"
		# 	print "input: ", x 
		# 	print "y_x: ", y_x
		# 	print "y_y: ", y_y
		# 	print i
		# 	#sum += error
		# 	n += 1
		# 	#print sum / n
		# 	print n
	print "trained"
	print model
	print "num_rfs ", model.num_rfs
	print "norm_in, ", model.norm_in
	print "norm_out ", model.norm_out
	print "mean_x ", model.mean_x
	print "var_x ", model.var_x
	print "rfs ", len(model.num_rfs)
	#print model.write_XML("model.xml") #check for NaNs
	toc = time.clock()
	print "Training Time: ", toc - tic
	print "test set performance..."
	sum = 0
	n = 0
	for i in range((len(train_data) - (STEP_SIZE + 1)) / SET_REDUCTION):
		# Get all x inputs except for command
		x = train_data[i + STEP_SIZE * SET_REDUCTION][0:INPUT_DIM]

		# Get all y outputs
		y_real = train_data[i + STEP_SIZE + 1 * SET_REDUCTION][1:OUTPUT_DIM + 1]
		
		# Get the command
		command = train_data[i + STEP_SIZE + 1 * SET_REDUCTION][COMMAND_START:]
		#pose = train_data[i + STEP_SIZE + 1 * SET_REDUCTION][0:3]

		# shift command to global coordinates from robot coordinates
		#command = transformCommand(pose, command)

		# Add command to inputs
		#x = np.append(x,command)
		
		# Predict
		y = model.predict(x)

		n += 1
		sum += linalg.norm(y_real - y)
	print "average error: ", sum / n

	print "validating..."
	sum = 0
	n = 0
	averageTime = 0
	tic = time.clock()
	for i in range((len(test_data) - (STEP_SIZE + 1)) / SET_REDUCTION):

		# Get all x inputs except for command
		x = test_data[i + STEP_SIZE * SET_REDUCTION][0:INPUT_DIM]

		# Get all y outputs
		y_real = test_data[i + STEP_SIZE + 1 * SET_REDUCTION][1:OUTPUT_DIM + 1]
		# Get the command
		command = test_data[i + STEP_SIZE + 1 * SET_REDUCTION][COMMAND_START:]
		#pose = train_data[i + STEP_SIZE + 1 * SET_REDUCTION][0:3]

		# Predict
		
		y = model.predict(x)
		

		averageTime += toc-tic
		with open("real.txt", "a") as myfile:
			myfile.write('\t'.join([str(x) for x in y_real]))
			myfile.write('\n')

		with open("predicted.txt", "a") as myfile:
			myfile.write('\t'.join([str(x) for x in y]))
			myfile.write('\n')
		
		n += 1
		sum += linalg.norm(y_real - y)
	toc = time.clock()
	print "average error: ", sum / n
	if(sum/n < best_sum):
		best_sum = sum / n
		best_index = iter
	print toc - tic
	print (toc - tic)/n
print "Best Sum: ", best_sum
print "Best Index: ", best_index