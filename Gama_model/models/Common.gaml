/**
* Name: Common
* Based on the internal empty template. 
* Author: Léon
* Tags: 
*/


model Common


global {
	int nb_buildings_row <- 8;
	float sizeOfWorld <- 2#km;
	map<string,species<building>> string_to_species <- ["residential_building"::residential_building,
		"commercial_building"::commercial_building,
		"industrial_building"::industrial_building,
		"empty_building"::empty_building];
	int nb_people <- 1000;
	geometry shape <- rectangle(sizeOfWorld,sizeOfWorld);
	float build_len <- sizeOfWorld/(nb_buildings_row*2);
	/* Importing the input CSV file, can be removed */
	matrix inputBuildinglayout <- matrix(csv_file("../includes/input_building_layout.csv",";"));
	graph road_network;
	float step <- 0.5 #mn;
	date starting_date <- date([2023,9,1,3,30]);
    int avg_work_start <- int(8.5*60);
    int avg_work_end <- int(17*60); 
    float var_gauss <- 100.0;
    int max_evening_shop <- 22*60;
    int max_party <- 3*60;
    float people_speed <- 2.5 #km / #h;
    
    action mouse_change_building{}
	
	float ratio_residential <- 0.68;
	float ratio_industrial <- 0.2;
	float ratio_commercial <- 0.1;

    
}

species building {
	float size <- build_len*2*0.8;
	list<people> people_inside;
	rgb color;
	string building_type;
	
	action add_people(people p) {
		people_inside << p;
	}
	
	int remove_people {
		int length <- length(people_inside);
		loop p over: people_inside {
			ask p {
				do die;
			}
		}
		people_inside <- [];
		return length;
	}
	
	aspect base {
	draw square(size) color: color;
	}
}

species empty_building parent: building{
	string building_type <- "empty_building";
	rgb color <- rgb(100,100,100);
}

species commercial_building parent: building {
	string building_type <- "commercial_building";
	rgb color <- rgb(64,170,208);
}

species industrial_building parent: building {
	string building_type <- "industrial_building";
	rgb color <- rgb(200,200,0);
}

species residential_building parent: building {
	string building_type <- "residential_building";
	rgb color <- rgb(50,205,50);
}

species road  {

} 

species people skills:[moving]{
	rgb color <- #red ;
	point offset;
	building living_place <- nil ;
    building working_place <- nil ;
    building shopping_place <- nil;
    int start_work ;
    int end_work  ;
    int start_evening_shop;
    int end_evening_shop;
    int start_party;
    int end_party;
    bool is_party_day;
    bool is_evening_shopping_day;
    string objective ; 
    point the_target <- nil ;
    
    bool compare(date cur_dat, int trigger_date) {
    	return cur_dat.hour*60 + cur_dat.minute = trigger_date;
    }
    
    init {
    	offset <- {rnd(-build_len/7,build_len/7),rnd(-build_len/7,build_len/7)};
    	speed <- people_speed;
        start_work <- int(gauss (avg_work_start, var_gauss));
        end_work <- int(gauss (avg_work_end, var_gauss));
        start_evening_shop <- rnd(end_work, (end_work+max_evening_shop)/2);
        end_evening_shop <- rnd(start_evening_shop, max_evening_shop);
        start_party <- rnd(end_evening_shop, (max_party+end_evening_shop)/2);
        end_party <- rnd(start_party, max_party);
        
        people p <- self;
        living_place <- one_of(residential_building) ;
        ask living_place {
        	do add_people(p);
        }
        working_place <- one_of(industrial_building) ;
        ask working_place {
        	do add_people(p);
        }
        objective <- "resting";
        location <- any_location_in (living_place); 
    }
    
    reflex today_feeling when:every(1#day){
    	is_party_day <- flip(0.2);
    	is_evening_shopping_day <- flip(0.4);
    }
    
    reflex time_to_party when: compare(current_date, start_party) and is_party_day and objective="resting" {
    	objective <- "party" ;
    	the_target <- any_location_in (one_of(residential_building));
    }
    
    reflex time_to_evening_shopping when: compare(current_date, start_evening_shop) and is_evening_shopping_day and objective="resting" {
    	objective <- "evening_shopping" ;
    	the_target <- any_location_in (one_of(commercial_building));
    }
    
    reflex time_to_work when: compare(current_date, start_work){
    	if flip(0.2) {
    		objective <- "shopping" ;
    		the_target <- any_location_in (one_of(commercial_building));
    	}
    	else {
    		objective <- "working" ;
    		the_target <- any_location_in (working_place);
    	}
    }
	
	reflex time_to_go_home when: (compare(current_date, end_work) and (objective = "working" or objective="shopping"))
	or (compare(current_date, end_evening_shop) and (objective="evening_shopping")) or (compare(current_date, end_party) and (objective = "party"))  {
        objective <- "resting" ;
    	the_target <- any_location_in (living_place); 
    }
    
    reflex move when: the_target != nil {
	    do goto target: the_target on: road_network ; 
	    if the_target = location {
	        the_target <- nil ;
	    }
    }
    
	aspect base {
		draw circle(build_len/15) color: color border:#black at: location + offset;
	}
}