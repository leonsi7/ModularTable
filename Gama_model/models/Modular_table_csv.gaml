/**
* Name: Modulartable1
* Based on the internal empty template. 
* Author: Léon
* Tags: 
*/


model Modulartable1

import "Common.gaml"

global {
	
	init {
		/* Creation of the roads */
		create road from: split_lines(union(building_grid collect each.shape.contour));	
		road_network <- as_edge_graph(road);	
	
		ask building_grid {
			do add_building_to_graph;
		}
		
		create people number: nb_people;

	}
	
	/* Refex updating buildings by re-reading the input csv file */
	reflex update_buildings when:every(1#second) {
		matrix newInputBuildinglayout <- matrix(csv_file("C:/Users/Léon/Workspaces/PythonWorkspace/IRD/Modular_table/input_building_layout.csv",";"));
		if length(newInputBuildinglayout) != 0 {
				ask building_grid {
				do swap_buildings(newInputBuildinglayout);
			}
			inputBuildinglayout <- newInputBuildinglayout;
		}
	}
}

grid building_grid width:nb_buildings_row  height:nb_buildings_row neighbors:4 {
	
	building buildingOn;
	
	init{
		do match_with_csv(inputBuildinglayout,grid_x, grid_y);
	}
	
	action match_with_csv(matrix inputMatrix,int i, int j){
		/**
		 * Action that update the building on grid position i,j by reading inputMatrix
		 */
		building_grid my_cell <- building_grid[i,j];
		switch inputMatrix[i, j] {
			
			match "r" {
				create residential_building returns:listAgent{
					//self.my_cell <- my_cell;
					location <- my_cell.location;
					
				}
				my_cell.buildingOn <- listAgent[0];	
			}
			match "i" {
				create industrial_building returns:listAgent{
					//self.my_cell <- my_cell;
					location <- my_cell.location;
				}
				my_cell.buildingOn <- listAgent[0];
				
			}
			match "c" {
				create commercial_building returns:listAgent{
					//self.my_cell <- my_cell;
					location <- my_cell.location;
				}
				my_cell.buildingOn <- listAgent[0];
			}
			default {
				create empty_building returns:listAgent{
					//self.my_cell <- my_cell;
					location <- my_cell.location;
				}
				my_cell.buildingOn <- listAgent[0];
			}
		}
	}
	
	action swap_buildings(matrix newInputBuildinglayout) {
		/** This action can be triggered and update building position */
		if newInputBuildinglayout[grid_x,grid_y] != inputBuildinglayout[grid_x,grid_y] {
			building_grid my_cell <- building_grid[grid_x, grid_y];
			int people_removed;
			ask my_cell.buildingOn {
				people_removed <- remove_people();
				do die;
			}
			do match_with_csv(newInputBuildinglayout,my_cell.grid_x, my_cell.grid_y);
			create people number:people_removed;
		}
	}
	
	action add_building_to_graph {
		/* This function adds the center of the building to the graph so that people can reach the road from their home/workshop */
		building_grid my_cell <- building_grid[grid_x, grid_y];
		road_network <- add_node(road_network, my_cell.location);
		road_network <- add_edge(road_network, my_cell.location::my_cell.location-{build_len,build_len});
	}
}

experiment modular_table_experiment type: gui {
	
	
	output {
		display main_display{
			species industrial_building aspect:base;
			species residential_building aspect:base;
			species commercial_building aspect:base;
			species empty_building aspect:base;
			species people aspect:base;
		}
		display chart_display refresh: every(10#cycles) {
			chart "People's activity" type: pie style: exploded size: {1, 0.5} position: {0, 0.5}{
				data "Working" value: people count (each.objective="working") color:   rgb(200,200,0);
				data "Resting" value: people count (each.objective="resting") color: rgb(50,205,50) ;
				data "Shopping" value: people count (each.objective="shopping") color: rgb(64,170,208) ;
      		}
      	}
	}
}
