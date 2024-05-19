extends Node

# ye best start believing in monoliths... cause yer in one!
# Elliot W. https://github.com/e-war


@export var register_gesture_as: String

var saved_gestures: Array
var save_location: String = "res://Script/Q$/gesture_data/"
var origin = Vector3(0,0,0)
var cloud_size: int = 32
var LUT_size: int = 64
var max_int_coord: int = 512
var LUTScaleFactor = max_int_coord / LUT_size


func _ready():
	load_gestures()

func SqrEuclideanDistance(point_a: Vector3,point_b: Vector3):
	var dx = point_b.x - point_a.x
	var dy = point_b.y - point_a.y
	return (dx * dx) + (dy * dy)
func EuclideanDistance(point_a: Vector3,point_b: Vector3):
	var s = SqrEuclideanDistance(point_a,point_b)
	return sqrt(s)


func sanitize_loaded_point(point):
	if(point is String):
		return string_vector_to_vector(point)
	else:
		return point
func path_length(points: Array[Vector3]):
	var length: float
	for x:int in range (1,len(points)):
		if(points[x].z == points[x-1].z):
			length += EuclideanDistance(points[x-1],points[x]) 
	return length
func point_to_3dpoint(point: Vector2):
	return Vector3(point.x,point.y,1) # temp 1 here just because we use only 1 line gesture atm

func resample_points(points: Array[Vector3]):
	var I = path_length(points) / (cloud_size - 1)
	var D: float
	var new_points: Array[Vector3]
	#new_points.resize(cloud_size)

	new_points.append(points[0])
	var new_point_counter:int = 1
	for x:int in range(1,len(points)):
		if(points[x].z == points[x-1].z):
			var d = EuclideanDistance(points[x-1],points[x])
			if(D+d >= I):
				'''var point0 = points[0]
				while (D+d>=I):#github.com/angrychill
					var t: float = min(max((I-D)/d,0.0),1.0)
					if(is_nan(t)):
						t = 0.5
					var new_point = Vector3((1.0-t) * point0.x + t * points[x].x,(1.0-t)*point0.y+t*points[x].y,points[x].z)
					new_points[new_point_counter] = new_point
					new_point_counter+=1
					
					d = D + d - I
					D=0
					point0 = new_points[new_point_counter - 1]
				D = d
			else:
				D += d
			'''
				var qx = points[x-1].x + (I - D) / d * (points[x].x - points[x-1].x) 
				var qy = points[x-1].y + (I - D) / d * (points[x].y - points[x-1].y )
				var q = Vector3(qx,qx,points[x].z)
				new_points.append(q)
				points.insert(x-1,q) # changed from og, not sure if x or x-1 is needed as x seems to make the path look useless
				D = 0.0
			else:
				D += d
	if(len(new_points) < cloud_size - 2): # if the line drawn is too short, we can have a len of something ~ 25, ensure that the line isn't confirmed unless it is less than what makes this crash :)
		print("TOO SHORT" + str(len(new_points)))
		
		var to_add = len(new_points) - (cloud_size -2)
		print(to_add)
		for x in range(0,-to_add):
			new_points.append(Vector3(points[len(points)-1].x,points[len(points)-1].y,points[len(points)-1].z))
	elif(len(new_points) >= cloud_size - 1):# if line is too long? no clue why this happens but it does sometimes. just drop the last needed points.
		var to_rem = len(new_points) - cloud_size
		for x in range(0, -to_rem):
			new_points.pop_back()
	return new_points
	
func scale_points(points: Array[Vector3]):
	var minX: float = INF
	var maxX: float = -INF
	var minY: float = INF
	var maxY: float = -INF
	
	for x:int in range(0,len(points)):
		if minX > points[x].x:
			minX = points[x].x
		if minY > points[x].y:
			minY = points[x].y
		if maxX < points[x].x:
			maxX = points[x].x
		if maxY < points[x].y:
			maxY = points[x].y
		
	var size = max(maxX - minX,maxY-minY)
	var new_points: Array[Vector3]
	for x: int in range(0,len(points)):
		var qx = (points[x].x - minX) / size
		var qy = (points[x].y - minY) / size
		new_points.append(Vector3(qx,qy,points[x].z))
	return new_points
	
func centroid(points: Array[Vector3]):
	var x = 0.0
	var y = 0.0
	for i:int in range(0,len(points)):
		x+=points[i].x
		y+=points[i].y
	x /= len(points)
	y /= len(points)
	return(Vector2(x,y))
func translate_points(points: Array[Vector3]):
	var c = centroid(points)
	var new_points: Array[Vector3]
	for x: int in range(0,len(points)):
		var qx = points[x].x + origin.x - c.x
		var qy = points[x].y + origin.y - c.y
		new_points.append(Vector3(qx,qy,points[x].z))
	return new_points
	
func points_to_ints(points: Array[Vector3]):
	var int_points:Array[Vector3]
	for x:int in range(0,len(points)):
		var ix = round((points[x].x + 1.0) / 2.0 * (max_int_coord - 1))
		var iy = round((points[x].y + 1.0) / 2.0 * (max_int_coord - 1))
		int_points.append(Vector3(ix,iy,points[x].z))
	return int_points
	
func calculate_LUT(int_points):
	var LUT: Array
	for a:int in range(0,LUT_size):
		var b: Array
		LUT.append(b)
	for x:int in range(0,LUT_size):
		for y:int in range(0,LUT_size):
			var u = -1
			var b: float = INF
			for i:int in range(0,len(int_points)):
				var row = round(int_points[i].x / LUTScaleFactor)
				var col = round(int_points[i].y / LUTScaleFactor)
				var d = ((row - x) * (row - x) + (col - y) * (col - y))
				if(d<b):
					b=d
					u=i
			LUT[x].append(u)
	return LUT
func normalize_points(points: Array[Vector3]):
	var normalized_points = resample_points(points)
	normalized_points = scale_points(normalized_points)
	normalized_points = translate_points(normalized_points)
	var interger_points = points_to_ints(normalized_points)
	var LUT = calculate_LUT(interger_points)
	return [normalized_points,interger_points,LUT]

func point_array_to_dict(gesture: Array):
	var g_DICT: Dictionary

	g_DICT["name"] = register_gesture_as
	g_DICT["points"] = gesture[0]
	g_DICT["int_points"] = gesture[1]
	g_DICT["LUT"] = gesture[2]
	return g_DICT

func save_gesture(gesture_dictionary):
	var temp = JSON.new()
	var g_JSON
	var f_read = ResourceLoader
	var f_write = ResourceSaver
	var save_name = register_gesture_as
	g_JSON = JSON.stringify(gesture_dictionary)
	 
	temp.parse(g_JSON)
	g_JSON = temp
	if(f_read.exists(save_location+"/"+save_name+".json")):
		var checker: bool 
		var i:int
		while !checker:
			if(!f_read.exists(save_location+"/"+save_name+str(i)+".json")):
				save_name = save_name+str(i)
				checker = true
			i += 1
	f_write.save(g_JSON,save_location+"/"+save_name+".json")

func load_gestures():
	var f_read = ResourceLoader#
	var dir = DirAccess.open(save_location)
	for x in dir.get_files():
		if(x.ends_with(".json")):
			var gesture_JSON = f_read.load(save_location+"/"+x) 
			var gesture_dict = gesture_JSON.data
			saved_gestures.append(gesture_dict)

func register_gesture(gesture_name, point_data: Curve2D):
	#make sure that the var register_gesture_as is set to the name of the gesture you want
	#call this function using your curve2d data to add a new gesture
	var baked_points = point_data.get_baked_points()
	var unpacked_points = Array(baked_points)
	if(len(unpacked_points) > 0):
		var new_points: Array[Vector3]
		for point in baked_points:
			# convert each point to point + index (in vector3)
			new_points.append(point_to_3dpoint(point))
		var gesture = normalize_points(new_points) # contains pointclouds + LUT
		var dict_gesture = point_array_to_dict(gesture)
		save_gesture(dict_gesture)

func string_vector_to_vector(string_vector: String):
	string_vector.replace("(","")
	string_vector.replace(")","")
	var vector_array: Array = string_vector.split(",")
	return Vector3(float(vector_array[0]),float(vector_array[1]),float(vector_array[2]))

func compute_lower_bound(points_a,points_b,step,LUT):
	var n = len(points_a["points"])
	print(n)
	var LB = Array()
	LB.resize(floor(n/step)+1)
	var SAT = Array()
	SAT.resize(n)
	LB[0] = 0.0
	for i:int in range(0,n):
		
		
		
		
		var x 
		var y
		
		# fixes bug ensure that these points are Vector3 as loading from JSON resets types to String.
		var p = sanitize_loaded_point(points_a["int_points"][i])
		x = round(p.x / LUTScaleFactor)
		y = round(p.y / LUTScaleFactor)
		var index = LUT[x][y]

		# fixes bug ensure that these points are Vector3 as loading from JSON resets types to String.
		var point_a = sanitize_loaded_point(points_a["points"][i])
		var point_b = sanitize_loaded_point(points_b["points"][i])
	
		var d = SqrEuclideanDistance(point_a,point_b)
		if(i == 0):
			SAT[i] = d
		else:
			SAT[i] = SAT[i-1] + d
		LB[0] = LB[0] + (n - i) * d
	var step_count = step
	var j:int = 1
	for i:float in range(step_count,n,step):
		LB[j] = LB[0] + i * SAT[n-1] - n * SAT[i-1]
		j+=1
	return LB

func cloud_distance(to_match_points,template_points,start,lowest_score):
	var n = len(to_match_points["points"])
	var unmatched: Array
	for j in range(0,n):
		unmatched.append(j)
	var i = start
	var weight = n
	var sum:float = 0.0
	
	while true:
		var u =-1
		var b: float = INF
		for j:int in range(0,len(unmatched)):
			var d = SqrEuclideanDistance(sanitize_loaded_point(to_match_points["points"][i]),sanitize_loaded_point(template_points["points"][unmatched[j]]))
			if(d<b):
				b=d
				u=j
		unmatched.remove_at(u)
		sum += weight * b
		if(sum >= lowest_score):
			print("POSITIVE")
			return sum
		weight -= 1
		
		i = int(i+1)%n
		print(i)
		if(i == start):
			print("GUESS")
			break
	return sum
	
func cloud_match(to_match_points,template_points,lowest_score):
	var n = len(to_match_points["points"])
	var step = floor(pow(n,.5))
	
	var LB1 = compute_lower_bound(to_match_points,template_points,step,template_points["LUT"])
	var LB2 = compute_lower_bound(template_points,to_match_points,step,to_match_points["LUT"])
	
	var j: int = 0
	for i: float in range(0, n, step):
		if(LB1[j] < lowest_score):
			lowest_score = min(lowest_score,cloud_distance(to_match_points,template_points,i,lowest_score))
		if(LB2[j] < lowest_score):
			lowest_score = min(lowest_score,cloud_distance(template_points,to_match_points,i,lowest_score))
		j+=1
	return lowest_score

func recognize(points: Array[Vector3]):
		var gesture = normalize_points(points) # contains pointclouds + LUT
		print("GESTURE:"+str(len(gesture[0])))
		var dict_gesture = point_array_to_dict(gesture)
		var u: float = -1
		var b: float = INF
		
		for x:int in range(0,len(saved_gestures)):
			var d = cloud_match(dict_gesture,saved_gestures[x],b)
			if d<b:
				b = d
				u = x
		var result 
		var score
		if(u == -1):
			result = null # no result
		else:
			result = saved_gestures[u]["name"]
		
		if b>1.0:
			score = 1.0/b
		else:
			score = 1.0
		print(result+" Score: "+str(score))
		
func recognize_curve(curve_data: Curve2D):
	var baked_points = curve_data.get_baked_points()
	var unpacked_points = Array(baked_points)
	if(len(unpacked_points) > 0):
		var new_points: Array[Vector3]
		for point in baked_points:
			# convert each point to point + index (in vector3)
			new_points.append(point_to_3dpoint(point))
		recognize(new_points)
