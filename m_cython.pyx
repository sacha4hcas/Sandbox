#python setup.py build_ext --inplace

import time
import pygame
import random
import array
from cpython cimport array

cdef class Base_Cell:
	cdef public int x
	cdef public int y
	cdef public Sandbox sandbox
	cdef public bint checked
	cdef public bint fluid
	cdef public float viscosity
	cdef public float mass

	def __init__(o, sandbox = None, pos = (0,0)):
		o.x = pos[0]
		o.y = pos[1]
		o.sandbox = sandbox
		o.checked = False

		o.fluid = True
		o.viscosity = 0 #between 0 and 1
		o.mass = 0

	cdef list get_pos(o):
		return [o.x, o.y]
	cdef list get_color(o):
		return [0,0,0]

	cdef update(o):
		pass
	
	cdef public update_color(o, surface):
		surface.set_at(o.get_pos(), o.get_color())
	
	cdef sink_into(o, cell):
		if cell is not None and cell.fluid and cell.mass < o.mass:
			o.sandbox.swap_cells(o, cell)
			return True
		return False

	cdef Base_Cell get_cell(o, i, j):
		if 0 <= o.x + i < o.sandbox.w and 0 <= o.y+j < o.sandbox.h:
			return o.sandbox.grid[o.x+i][o.y+j]
		else: return None
	
	def __repr__(o):
		return "0"

cdef class Sand_Cell(Base_Cell):
	def __init__(o, sandbox = None, pos = (0,0)):
		Base_Cell.__init__(o, sandbox, pos)
		o.mass = 0.8

	cdef update(o):
		if o.sink_into(o.get_cell(0, -1)): return
		if random.random() > 0.5: x = 1
		else : x = -1
		if o.sink_into(o.get_cell(x, -1)): return
		if o.sink_into(o.get_cell(-x,-1)): return

	cdef list get_color(o):
		return [76, 70, 50]
	
	def __repr__(o):
		return "1"

cdef class Water_Cell(Base_Cell):
	def __init__(o, sandbox = None, pos = (0,0)):
		Base_Cell.__init__(o, sandbox, pos)
		o.mass = 0.1

	cdef update(o):
		if o.sink_into(o.get_cell(0, -1)): return
		if random.random() > 0.5: x = 1
		else : x = -1
		if o.sink_into(o.get_cell(x, -1)): return
		if o.sink_into(o.get_cell(-x,-1)): return
		if o.sink_into(o.get_cell(x, 0)): return
		if o.sink_into(o.get_cell(-x, 0)) : return
	
	cdef list get_color(o):
		return [35, 137, 218]

	def __repr__(o):
		return "2"

cdef class Sandbox:
	cdef public object grid
	cdef public object surface
	cdef public int w
	cdef public int h

	def __init__(o, w, h):
		
		
		o.w = w
		o.grid = [[Base_Cell(o, [i, j]) for j in range(h)] for i in range(w)]
		o.h = h
		o.surface = pygame.Surface([w, h])
		
		#o.surface = pygame.transform.scale(o.surface, (screen_w, screen_h))
		#o.surface = pygame.transform.flip(o.surface, False, True)

	cdef swap_cells(o, cell1, cell2):
		o.grid[cell1.x][cell1.y], o.grid[cell2.x][cell2.y] = cell2, cell1
		cell1.x, cell2.x = cell2.x, cell1.x
		cell1.y, cell2.y = cell2.y, cell1.y

		cell1.update_color(o.surface)
		cell2.update_color(o.surface)

	cdef insert_cell(o, cell, pos):
		cell.x = pos[0]
		cell.y = pos[1]
		cell.sandbox = o
		o.grid[pos[0]][pos[1]] = cell
		cell.update_color(o.surface)


	cdef sync_surface(o):
		for cells in o.grid:
			for cell in cells:
				cell.update_color(o.surface)

	
	cdef update_cell(o, cell):
		if not cell.checked:
			cell.update()
			cell.checked = True


	cdef update_cells(o):
		rand = 1#random.random()
		if rand > 0.75:
			for cells in o.grid:
				for cell in cells:
					o.update_cell(cell)
		elif rand > 0.5:
			for cells in reversed(o.grid):
				for cell in cells:
					o.update_cell(cell)
		elif rand > 0.25:
			for cells in o.grid:
				for cell in reversed(cells):
					o.update_cell(cell)
		else:
			for cells in reversed(o.grid):
				for cell in reversed(cells):
					o.update_cell(cell)

		for cell in o.cells:
			cell.checked = False

	cdef Base_Cell get_cell_by_pixel(o, pos, x_scale, y_scale):
		x_cell = int(pos[0] // x_scale)
		y_cell = int(pos[1] // y_scale)
		y_cell = o.h - y_cell - 1

		return o.grid[x_cell][y_cell]



cdef class Simulation:
	cdef Sandbox sandbox
	cdef int screen_w
	cdef int screen_h
	cdef int max_fps
	cdef float scale_x
	cdef float scale_y
	cdef object screen
	cdef float frame_limit
	cdef float frame_timer
	cdef int time_fps
	cdef int frames
	cdef object time_measure
	cdef object cell_maker

	def __init__(o, sandbox, screen_w = 420, screen_h = 420, max_fps = 60):
		o.sandbox = sandbox

		o.screen_w = screen_w
		o.screen_h = screen_h
		o.scale_x = screen_w / sandbox.w
		o.scale_y = screen_h / sandbox.h
		pygame.init()
		o.screen = pygame.display.set_mode([o.screen_w, o.screen_h])
		
		o.frame_limit = 1/max_fps
		o.time_fps = time.time()
		o.frames = 0
		o.frame_timer = time.time()
		o.time_measure = {"update_cells" : [], "sync_surface" : [], "draw" : []}
		

		o.cell_maker = lambda : Sand_Cell()


	def run(o):
		running = True
		mouse_pressed = False
		pause = True
		while running:
			for event in pygame.event.get():
				if event.type == pygame.QUIT:
					print(o.time_measure)
					running = False
					pygame.quit
				if event.type == pygame.MOUSEBUTTONDOWN:
					mouse_pressed = True
				if event.type == pygame.MOUSEBUTTONUP:
					mouse_pressed = False
				if event.type == pygame.KEYDOWN:
					if event.key == pygame.K_p:
						pause = not pause
					if event.key == pygame.K_KP1:
						o.cell_maker = lambda : Sand_Cell()
					if event.key == pygame.K_KP2:
						o.cell_maker = lambda : Water_Cell()
					if event.key == pygame.K_KP3:
						print(o.sandbox)
					if event.key == pygame.K_KP_ENTER:
						o.sandbox.update_cells()

					if event.key == pygame.K_d:
						with open("time_measure.json", "w") as output:
							output.write(str(o.time_measure))
						print("update_cells | sync_surface " + "\n" + 
								str(o.time_measure["update_cells"][-1])[0:7] + "      | " +
								str(o.time_measure["sync_surface"][-1])[0:7] + "      | ")
			if mouse_pressed:
				o.insert_new_cell()

			if not pause and time.time() - o.time_fps >= 1:
				print(o.frames)
				o.frames = 0
				o.time_fps = time.time()
			if not pause and time.time() - o.frame_timer > o.frame_limit:
				o.frame_timer += o.frame_limit
				timer = time.time()
				o.sandbox.update_cells()
				o.time_measure["update_cells"].append(time.time() - timer)
				o.frames+=1

			o.blit_sandbox()
			pygame.display.update()
			
			
	cdef insert_new_cell(o):
		mouse_pos = pygame.mouse.get_pos()
		#print(mouse_pos)
		cell_pos = o.sandbox.get_cell_by_pixel(mouse_pos, o.scale_x, o.scale_y).get_pos()
		#print(cell_pos)
		o.sandbox.insert_cell(o.cell_maker(), cell_pos)
		#print(sandbox.__repr__())


	cdef blit_sandbox(o):
		timer = time.time()
		#o.sandbox.update_surface()
		o.time_measure["sync_surface"].append(time.time() - timer)
		surface = o.sandbox.surface
		surface = pygame.transform.scale(o.sandbox.surface, (o.screen_w, o.screen_h))
		surface = pygame.transform.flip(surface, False, True)
		o.screen.blit(surface, (0,0))


