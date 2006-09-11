/*
 *  TVLEdit.cpp
 *  Vocalese
 *
 *  Created by Matthias Neeracher on 12/19/05.
 *  Copyright 2005 __MyCompanyName__. All rights reserved.
 *
 */

#include "VLModel.h"

#include <iostream>

std::istream & operator>>(std::istream & s, VLFraction & f)
{
	int num, n, d;
	char c;

	s >> num >> c;
	if (c == '.') {
		s >> n >> c >> d;
		
		f = num + VLFraction(n, d);
	} else {
		s >> d;

		f = VLFraction(num, d);
	}

	return s;
}

std::ostream & operator<<(std::ostream & s, VLFraction f)
{
	int whole = f.fNum / f.fDenom;

	if (whole) {
		s << whole;
		f -= whole;
		if (f.fNum)
			s << int(f.fNum) << '/' << int(f.fDenom);
	} else if (f.fNum) {
		s << int(f.fNum) << '/' << int(f.fDenom);
	} else {
		s << '0';
	}
	return s;
}

void PrintName(const VLNote & note) 
{
	std::string name;
	note.Name(name, false);
	std::cout << name;
}

void PrintName(const VLChord & chord) 
{
	if (chord.fPitch == VLNote::kNoPitch) {
		std::cout << 's';
	} else {
		std::string base,ext,root;
		chord.Name(base, ext, root, false);
		std::cout << base << '[' << ext << ']' << root;
	}
}

template <class C> class Printer {
	VLProperties *	fProp;
	VLFraction      fAt;
public:
	Printer(VLProperties * prop) : fProp(prop) {}
	
	void operator()(const C& obj) {
		PrintName(obj);

		std::cout << '@';
		for (VLFraction d = obj.fDuration; d > 0; ) {
			VLFraction p;
			fProp->PartialNote(fAt, d, &p);
			if (d < obj.fDuration)
				std::cout << '+';
			std::cout << p;
			d	-= p;
			fAt += p;
		}
		std::cout << ' ';
	}
};

void PrintMeasure(const VLMeasure & measure)
{
	std::for_each(measure.fChords.begin(), measure.fChords.end(), 
				  Printer<VLChord>(measure.fProperties));
	std::cout << std::endl;
	std::for_each(measure.fMelody.begin(), measure.fMelody.end(), 
				  Printer<VLNote>(measure.fProperties));
	std::cout << std::endl << std::endl;	
}

void PrintSong(const VLSong & song)
{
	std::for_each(song.fMeasures.begin(), song.fMeasures.end(), PrintMeasure);
}

int main(int, char *const [])
{
	VLSong song;

	song.fMeasures.resize(4);

	char	command;
	while (std::cin >> command) {
		int 		measure;
		VLFraction 	at;
		std::string name;
		switch (command) {
		case '+':
			std::cin >> name >> measure >> at;
			song.AddNote(name, measure, at);
			
			PrintSong(song);
			break;
		case '-':
			std::cin >> measure >> at;
			song.DelNote(measure, at);
			
			PrintSong(song);
			break;
		case '&':
			std::cin >> name >> measure >> at;
			song.AddChord(name, measure, at);
			
			PrintSong(song);
			break;
		case '^':
			std::cin >> measure >> at;
			song.DelChord(measure, at);
			
			PrintSong(song);
			break;
		}
	}
	exit(0);
}
