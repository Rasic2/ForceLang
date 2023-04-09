const fs = require("fs");

fs.readFile("./POSCAR", "utf-8", (err, text) => {
  if (err) {
    console.error(err);
    return;
  }

  let lines = text.split("\n");
  // determine selective dynamics
  if (lines[7].toLowerCase().startsWith("s")) {
    coords = lines.splice(9);
    Relaxed = /T/;

    // relaxed atoms indexes
    relaxed_indexes = [];
    for (i in coords) {
      if (Relaxed.exec(coords[i])) {
        relaxed_indexes.push(Number(i));
      }
    }
  }
  fs.readFile("./OUTCAR", "utf8", (err, text) => {
    if (err) {
      console.error(err);
      return;
    }

    let lines = text.split("\n");
    let force = [];
    let drift = [];
    let TotalForce = /TOTAL-FORCE/;
    let TotalDrift = /total drift/;

    for (let index in lines) {
      let line = lines[index];
      let match_force = TotalForce.exec(line);
      let match_drift = TotalDrift.exec(line);

      if (match_force) {
        force.push(index);
      }
      if (match_drift) {
        drift.push(index);
      }
    }
    let force_xyz = [];
    for (i in force) {
      start = Number(force[i]) + 2;
      end = Number(drift[i]) - 1;

      // atom forces in each step
      step_atoms = lines.slice(start, end);

      // arrow func => sum(sum(f_i **2) for each atom)
      let step_force = (x) => {
        let inner_force = [];

        for (atom_index in x) {
          atom_list = [];
          if (relaxed_indexes.indexOf(Number(atom_index)) != -1) {
            x[atom_index]
              .trim()
              .split(/\s+/)
              .forEach((item) => {
                atom_list.push(Number(item));
              });
            inner_force.push(
              atom_list
                .slice(3, 6)
                .map((item) => item ** 2)
                .reduce((x, y) => x + y)
            );
          }
        }
        return inner_force.reduce((x, y) => x + y);
      };

      // calculate the RMS
      console.log(
        (Number(i) + 1).toString() +
          " FORCES: RMS = " +
          Math.sqrt(step_force(step_atoms) / step_atoms.length)
      );
    }
  });
});
