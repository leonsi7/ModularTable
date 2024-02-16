/**
* Name: Modulartable1
* Based on the internal empty template. 
* Author: Léon
* Tags: 
*/
model Modulartable2


import "Common.gaml"


global {
	
	
	init {
		
		/*Creation of the road network*/
		create road from: split_lines(union(building_grid collect each.shape.contour));	
		road_network <- as_edge_graph(road);	
		
		//Adding the entrance of the building to the road network
		ask building_grid {
			building_grid my_cell <- building_grid[grid_x, grid_y];
			road_network <- add_node(road_network, my_cell.location);
			road_network <- add_edge(road_network, my_cell.location::my_cell.location-{build_len,build_len});
		}
		
		
		/*Creation of people */
		create people number: nb_people;
		
		
	}
	
}

grid building_grid width:nb_buildings_row  height:nb_buildings_row neighbors:4 {
	
	building building_on;
	
	init{
		building_grid current_cell <- building_grid[grid_x,grid_y];
		create rnd_choice([residential_building::ratio_residential,industrial_building::ratio_industrial,commercial_building::ratio_commercial]) returns:listAgent {
			location <- current_cell.location;
		}
		current_cell.building_on <- listAgent[0];	
	}
	
	action change_building(string building_type, int i, int j) {
		/** This action can be triggered and update building position */
		if building_type != building_grid[i,j].building_on.building_type {
			building_grid my_cell <- building_grid[i, j];
			
			// Deletion of the building and the people living inside
			int people_removed <- 0;
			ask my_cell.building_on {
				people_removed <- remove_people();
				do die;
			}
			
			//Creation of the new building and adding in the world the same amount of people deleted
			create string_to_species[building_type] returns:listAgent{
					location <- my_cell.location;
					
				}
				my_cell.building_on <- listAgent[0];
			create people number:people_removed;
		}
	}
}

experiment modular_table_experiment type: gui {
	
	parameter "Number of people" var: nb_people min:0 max:1000 category: "People";
	parameter "Ratio residential"  var: ratio_residential min:0.0 max:1.0 category: "Buildings";
	parameter "Ratio industrial"  var: ratio_industrial min:0.0 max:1.0 category: "Buildings";
	parameter "Ratio commercial"  var: ratio_commercial min:0.0 max:1.0 category: "Buildings";
	
	action mouse_change_building {
		point loc <- #user_location; 
      	building_grid selected_cell <- building_grid(#user_location);
      	
      	switch selected_cell.building_on.building_type {
      		match "residential_building" {
      			ask selected_cell {
      				do change_building("commercial_building",self.grid_x,self.grid_y);
      			}
      		}
      		match "commercial_building" {
      			ask selected_cell {
      				do change_building("industrial_building",self.grid_x,self.grid_y);
      			}
      		}
      		match "industrial_building" {
      			ask selected_cell {
      				do change_building("residential_building",self.grid_x,self.grid_y);
      			}
      		}
      		match "empty_building" {
      			ask selected_cell {
      				do change_building("residential_building",self.grid_x,self.grid_y);
      			}
      		}
      	}
	}
	
	output {
		
				
		display main_display{
			species industrial_building aspect:base;
			species residential_building aspect:base;
			species commercial_building aspect:base;
			species empty_building aspect:base;
			species people aspect:base;
			event #mouse_up action: mouse_change_building; 
		}
		
		
		monitor "Current date" value: current_date; 
		display chart_display refresh: every(10#cycles) {
			
			
			chart "People's activity" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
				data "Working" value: people count (each.objective="working") color:   rgb(200,200,0);
				data "Resting" value: people count (each.objective="resting") color: rgb(50,205,50) ;
				data "Shopping" value: people count (each.objective="shopping" or each.objective="evening_shopping") color: rgb(64,170,208) ;
				data "Party" value: people count (each.objective="party") color: #pink ;
      		}
      	}
      	
      	
	}
}
