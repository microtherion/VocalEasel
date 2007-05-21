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
			s << '.' << int(f.fNum) << '/' << int(f.fDenom);
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

void ChordPrinter(const VLChord & chord)
{
	PrintName(chord);
	if (chord.fDuration != VLFraction(1,4))
		std::cout << " * " << chord.fDuration;
	std::cout << ' ';
}

void NotePrinter(const VLLyricsNote & note)
{
	if (note.fTied & VLNote::kTiedWithPrev)
		std::cout << "~ ";
	PrintName(note);
	std::cout << ' ' << note.fDuration 
			  << '[' << ((note.fVisual & VLNote::kTriplet) ? "T" : "")
			  << (note.fVisual & VLNote::kNoteHead)["124863"] << "] ";
}

void PrintMeasure(const VLMeasure & measure, const VLProperties & prop)
{
	std::for_each(measure.fChords.begin(), measure.fChords.end(), ChordPrinter);
	std::cout << std::endl;
	VLNoteList decomposed;
	measure.DecomposeNotes(prop, decomposed);
	std::for_each(decomposed.begin(), decomposed.end(), NotePrinter);
	std::cout << std::endl << std::endl;	
}

void PrintSong(const VLSong & song)
{
	for (size_t i=0; i<song.CountMeasures()-song.EmptyEnding(); ++i)
		PrintMeasure(song.fMeasures[i], song.fProperties[song.fMeasures[i].fPropIdx]);
}

int main(int, char *const [])
{
	VLSong song;

	char	command;
	while (std::cin >> command) {
		int 		measure;
		VLFraction 	at;
		std::string name;
		switch (command) {
		case '+':
			std::cin >> name >> measure >> at;
			song.AddNote(VLNote(name), measure, at);
			
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
